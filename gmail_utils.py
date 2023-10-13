import os.path

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

import base64
from email.message import EmailMessage


def obtain_gmail_credentials(token):
    """Shows basic usage of the Gmail API.
    Lists the user's Gmail labels.
    """
    creds = Credentials.from_authorized_user_info(token)
    token_refreshed = False

    # If there are no (valid) credentials available, let the user log in.
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
            token_refreshed = True
        # else:
        #     flow = InstalledAppFlow.from_client_config(client_config=credentials, scopes=["https://www.googleapis.com/auth/gmail.send"])
        #     creds = flow.run_local_server(port=0, open_browser=False)
        # Save the credentials for the next run

        # with open(token_file_name, 'w') as token:
        #     token.write(creds.to_json())

    return token_refreshed, creds


def gmail_send_message(creds, message_body, receiver, subject):
    """Create and send an email message
    Print the returned  message id
    Returns: Message object, including message id
    """

    try:
        service = build('gmail', 'v1', credentials=creds)
        message = EmailMessage()

        message.set_content(message_body)

        message['To'] = receiver
        message['Subject'] = subject

        # encoded message
        encoded_message = base64.urlsafe_b64encode(message.as_bytes()) \
            .decode()

        create_message = {
            'raw': encoded_message
        }
        # pylint: disable=E1101
        send_message = (service.users().messages().send
                        (userId="me", body=create_message).execute())
        print(F'Message Id: {send_message["id"]}')
    except HttpError as error:
        print(F'An error occurred: {error}')
        send_message = None
    return send_message
