import time
import sys
import requests
import json
from appwrite.client import Client
from appwrite.services.databases import Databases

appwrite_endpoint = "http://localhost/v1"
project_id = "6559a9f8f3d4cbd3a42c"
user_email = "kabiratvedika@gmail.com"
password = "Mementomori!3210"
appwrite_client = sys.argv[1]


def create_console_account():
    url = appwrite_endpoint + "/account"

    consoleLoginPayload = json.dumps({
        "userId": "root",
        "email": user_email,
        "password": password,
        "name": "Kabir Sihag"
    })

    headers = {
        'X-Appwrite-Project': 'console',
        'Content-Type': 'application/json'
    }

    response = requests.request("POST", url, headers=headers, data=consoleLoginPayload)
    print(response)
    # if not response.ok:
    #     raise Exception("Error creating console session. \nStatus: {} \nResponseBody: {}".format(response.status_code,
    #                                                                                              response.text))


def create_console_session():
    url = appwrite_endpoint + "/account/sessions/email"

    consoleLoginPayload = json.dumps({
        "email": user_email,
        "password": password
    })
    headers = {
        'X-Appwrite-Project': 'console',
        'Content-Type': 'application/json'
    }

    response = requests.request("POST", url, headers=headers, data=consoleLoginPayload)
    if not response.ok:
        raise Exception("Error creating console session. \nStatus: {} \nResponseBody: {}".format(response.status_code,
                                                                                                 response.text))

    cookie_res = response.headers['Set-Cookie']
    delimiters = [",", ";"]

    for delimiter in delimiters:
        string = " ".join(cookie_res.split(delimiter))
    cookie_res = cookie_res.split()

    cookie_req = ""
    for item in cookie_res:
        if item.startswith("a_session"):
            cookie_req = cookie_req + item
    return cookie_req


def get_console_session():
    url = appwrite_endpoint + "/account/"

    payload = "\n"
    headers = {
        'X-Appwrite-Project': 'console',
        'Content-Type': 'application/json',
        'Cookie': "{}".format(cookie)
    }

    response = requests.request("GET", url, headers=headers, data=payload)
    if not response.ok:
        raise Exception("Error getting console session. \nStatus: {} \nResponseBody: {}".format(response.status_code,
                                                                                                response.text))

    return response.text


def create_team():
    url = appwrite_endpoint + "/teams"

    consoleLoginPayload = json.dumps({
        "name": "OrgProjects",
        "teamId": "unique()"
    })

    headers = {
        'X-Appwrite-Project': 'console',
        'Content-Type': 'application/json',
        'Cookie': "{}".format(cookie)
    }

    response = requests.request("POST", url, headers=headers, data=consoleLoginPayload)
    print(response)
    if not response.ok:
        raise Exception("Error creating console session. \nStatus: {} \nResponseBody: {}".format(response.status_code,
                                                                                                 response.text))
    return json.loads(response.text)["$id"]


def create_project(orgId):
    url = appwrite_endpoint + "/projects"

    payload = json.dumps({
        "projectId": project_id,
        "name": "VedikaOrganics",
        "teamId": orgId,
        "region": "default"
    })
    headers = {
        'X-Appwrite-Project': 'console',
        'Content-Type': 'application/json',
        'Cookie': "{}".format(cookie)
    }

    response = requests.request("POST", url, headers=headers, data=payload)
    return response


def add_platform():
    print("adding web platform: {}".format(appwrite_client))
    url = appwrite_endpoint + "/projects/{}/platforms".format(project_id)

    payload = json.dumps({
        "type": "web",
        "name": "Web client",
        "hostname": appwrite_client
    })

    headers = {
        'X-Appwrite-Project': 'console',
        'Content-Type': 'application/json',
        'Cookie': "{}".format(cookie)
    }

    response = requests.request("POST", url, headers=headers, data=payload)
    print(response)
    if not response.ok:
        raise Exception("Error adding platform. \nStatus: {} \nResponseBody: {}".format(response.status_code,
                                                                                                response.text))



def create_database_read_write_key():
    url = appwrite_endpoint + "/projects/{}/keys".format(project_id)

    payload = json.dumps({
        "name": "db_read_write",
        "scopes": [
            "databases.read",
            "databases.write",
            "collections.read",
            "collections.write",
            "attributes.read",
            "attributes.write",
            "indexes.read",
            "indexes.write",
            "documents.read",
            "documents.write"
        ]
    })
    headers = {
        'X-Appwrite-Project': 'console',
        'Content-Type': 'application/json',
        'Cookie': "{}".format(cookie)
    }

    response = requests.request("POST", url, headers=headers, data=payload)

    if not response.ok:
        raise Exception("Error creating database read write key. \nStatus: {} \nResponseBody: {}".format(response.status_code,
                                                                                                 response.text))


    return json.loads(response.text)["secret"]


def create_users_read_key():
    url = appwrite_endpoint + "/projects/{}/keys".format(project_id)

    payload = json.dumps({
        "name": "users_read",
        "scopes": [
            "users.read"
        ]
    })
    headers = {
        'X-Appwrite-Project': 'console',
        'Content-Type': 'application/json',
        'Cookie': "{}".format(cookie)
    }

    response = requests.request("POST", url, headers=headers, data=payload)

    return json.loads(response.text)["secret"]


# def appwrite_login(username, password):
#     child = pexpect.spawn('appwrite login')
#     child.expect('Enter your email')
#     child.sendline(username)
#     child.expect('Enter your password')
#     child.sendline(password)
#     child.expect(pexpect.EOF)
#     print(child.before.decode())


def create_database(database_id):
    client = Client()

    (client
     .set_endpoint(appwrite_endpoint)  # Your API Endpoint
     .set_project(project_id)  # Your project ID
     .set_key(database_read_write_key)  # Your secret API key
     )

    databases = Databases(client)

    result = databases.create(database_id, "main")


def create_collection(collection):
    result = databases.create_collection(
        collection["databaseId"],
        collection["$id"],
        collection["name"],
        permissions=collection["$permissions"],
        document_security=collection["documentSecurity"],
        enabled=collection["enabled"])

    attributes = collection["attributes"]
    for attribute in attributes:
        create_attribute(attribute, collection["$id"])

    indexes = collection["indexes"]
    for index in indexes:
        databases.create_index(
            database_id,
            collection["$id"],
            index["key"],
            index["type"],
            index["attributes"],
            orders=index["orders"])


def create_attribute(attribute, collection_id):
    if attribute["type"] == "boolean":
        databases.create_boolean_attribute(
            database_id,
            collection_id,
            attribute["key"],
            attribute["required"],
            default=attribute["default"],
            array=attribute["array"]
        )
    if attribute["type"] == "string":
        databases.create_string_attribute(
            database_id,
            collection_id,
            attribute["key"],
            attribute["size"],
            attribute["required"],
            default=attribute["default"],
            array=attribute["array"]
        )
    if attribute["type"] == "integer":
        databases.create_integer_attribute(
            database_id,
            collection_id,
            attribute["key"],
            attribute["required"],
            min=attribute["min"],
            max=attribute["max"],
            default=attribute["default"],
            array=attribute["array"]
        )

    while True:
        print("checking attribute status for {}...".format(attribute["key"]), end='')
        res = databases.get_attribute(database_id, collection_id, attribute["key"])
        print(res["status"])
        if (res["status"] == "available"):
            break

##################################################################################

print("Creating accounts")
create_console_account()
cookie = create_console_session()

response = get_console_session()

orgId = None
if "organization" in json.loads(response)["prefs"]:
    orgId = json.loads(response)["prefs"]["organization"]
else:
    orgId = create_team()

create_project(orgId)
add_platform()

database_read_write_key = create_database_read_write_key()
users_read_key = create_users_read_key()

# appwrite_login(user_email, password)

client = Client()

(client
 .set_endpoint(appwrite_endpoint)  # Your API Endpoint
 .set_project(project_id)  # Your project ID
 .set_key(database_read_write_key)  # Your secret API key
 )

databases = Databases(client)
database_id = None
with open('appwrite.json') as json_file:
    data = json.load(json_file)
    database_id = data["databases"][0]["$id"]
    create_database(database_id)

    collections = data["collections"]
    for collection in collections:
        create_collection(collection)


variantsCollectionId = '6559aa721adfa29ca781'
offersCollectionId = '65c72d9e77f40389fe32'

variants_file = "variants.json"
offers_file = "offers.json"


def create_document(document, collection_id):
    docId = document['$id']
    del document['$id']
    del document['$databaseId']
    del document['$collectionId']
    print(document)
    databases.create_document(
        database_id=database_id,
        collection_id=collection_id,
        document_id=docId,
        data=document
    )


def upload_data(file_path, collectionId):
    with open(file_path, 'r') as json_file:
        data = json.load(json_file)
        documents_list = data['documents']
        for document in documents_list:
            create_document(document, collectionId)


def dump_api_keys():
    text_to_dump = ""
    text_to_dump = text_to_dump + "APPWRITE_DATABASE_WRITE_KEY={}".format(database_read_write_key)
    text_to_dump = text_to_dump + " " + "APPWRITE_USERS_API_KEY={}".format(users_read_key)
    with open("../appwrite-deployment/.appwrite_keys", "w") as file:
        # Write the text to the file
        file.write(text_to_dump)


upload_data(offers_file, offersCollectionId)
upload_data(variants_file, variantsCollectionId)

dump_api_keys()