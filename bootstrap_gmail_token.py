import json
import pathlib
import sys

from google_auth_oauthlib.flow import InstalledAppFlow

token_file_path = "token.json"

if pathlib.Path(token_file_path).exists():
    sys.exit(0)

with open("credentials.json", 'r') as creds:
    credentials = json.loads(creds.read())

print(credentials)
flow = InstalledAppFlow.from_client_config(client_config=credentials, scopes=["https://www.googleapis.com/auth/gmail.send"])
creds = flow.run_local_server(port=0)


with open(token_file_path, 'w') as token:
    token.write(creds.to_json())
