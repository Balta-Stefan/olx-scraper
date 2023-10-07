import logging
import boto3
from botocore.exceptions import ClientError
import os


s3_client = boto3.client('s3')
ssm_client = boto3.client('ssm')


def get_parameter_from_parameter_store(name, is_secret):
    response = ssm_client.get_parameter(Name=name, WithDecryption=is_secret)
    return response["Parameter"]["Value"]


def download_file(file_name, bucket, object_name=None):
    if object_name is None:
        object_name = os.path.basename(file_name)

    try:
        s3_client.download_file(bucket, object_name, file_name)
    except ClientError as e:
        response_code = e.response['Error']['Code']
        if response_code == '403' or response_code == '404':
            return False
        else:
            raise "Couldn't get the file, HTTP code " + e.response['Error']['Code']

    return True


def upload_file(file_name, bucket, object_name=None):
    """Upload a file to an S3 bucket

    :param file_name: File to upload
    :param bucket: Bucket to upload to
    :param object_name: S3 object name. If not specified then file_name is used
    :return: True if file was uploaded, else False
    """

    # If S3 object_name was not specified, use file_name
    if object_name is None:
        object_name = os.path.basename(file_name)

    # Upload the file

    try:
        response = s3_client.upload_file(file_name, bucket, object_name)
        logging.info(response)
    except ClientError as e:
        logging.error(e)
        return False
    return True


def delete_directory(bucket, directory):
    if directory[-1] != "/":
        directory += "/"

    objects = s3_client.list_objects(Bucket=bucket, Prefix=directory)

    for object in objects['Contents']:
        s3_client.delete_object(Bucket=bucket, Key=object['Key'])

    s3_client.delete_object(Bucket=bucket, Key=directory)