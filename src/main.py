import json
import requests
import os
import sys
import logging
import boto3
import dictdiffer

logging.basicConfig(level=logging.INFO)

def post_slack_message(slack_channel, slack_token, message):
    body = [{
        "type": "section",
        "text": {
            "type": "mrkdwn",
            "text": message
        }
    }]

    try:
        response = requests.post('https://slack.com/api/chat.postMessage', {
            'token': slack_token,
            'channel': slack_channel,
            'blocks': json.dumps(body)
        }).json()

        if not response["ok"]:
            incoming_req = "Channel: {} \nMessage: {}".format(slack_channel, message)
            logging.error("Incoming Request:\n%s" % incoming_req)
            logging.error("Failed to send slack notification:\n%s", response)
    except requests.exceptions.RequestException as e:
        incoming_req = "Channel: {} \nMessage: {}".format(slack_channel, message)
        logging.error("Incoming Request:\n%s" % incoming_req)
        logging.error("Failed to send slack notification:\n%s" % e)


def delete_items(db_client, db_table):
    table = db_client.Table(db_table)
    response = table.scan()
    for each in response['Items']:
        table.delete_item(
            Key = {
                'Data': each['Data']
            }
        )

def get_item(db_client, db_table):
    table = db_client.Table(db_table)
    response = table.scan()

    return json.loads(response['Items'][0]['Data'])

def put_item(db_client, db_table, data):
    table = db_client.Table(db_table)
    table.put_item(
        Item={
                'Data': data,
            }
        )

def lambda_handler(event, context):
    db_client = boto3.resource('dynamodb')
    db_table = os.environ.get("DB_TABLE_NAME")
    slack_token = os.environ.get("SLACK_TOKEN")
    slack_channel = os.environ.get("SLACK_CHANNEL")

    payload = json.loads(event['body'])
    features = payload['features']

    # Fetch old features set from DB
    old_features = get_item(db_client, db_table)

    # Store new features set into DB
    delete_items(db_client, db_table)
    put_item(db_client, db_table, json.dumps(features))

    for diff in list(dictdiffer.diff(old_features, features)):
        if diff[0] == 'change':
            message = "*{}* flag is updated\n>{}".format(diff[1][0], features[diff[1][0]])
        elif diff[0] == 'add':
            message = "*{}* flag is added\n>{}".format(diff[2][0][0], diff[2][0][1])
        elif diff[0] == 'remove':
            message = "*{}* flag is removed\n>{}".format(diff[2][0][0], diff[2][0][1])
        post_slack_message(slack_channel, slack_token, message)

    return { 'statusCode': 200 }
