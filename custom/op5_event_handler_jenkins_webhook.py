#!/usr/bin/env python

from __future__ import print_function
import sys
import os
import argparse
import requests

def Create_Webhook_Request(jenkins_server,webhook_token,json_data):    
    r = requests.post('http://httpbin.org/post', data = {'key':'value'})
    r.text      # response as a string
    r.content   # response as a byte string
     #     gzip and deflate transfer-encodings automatically decoded 
    r.json()    # return python object from json! this is what you probably want!
    return webhook

def Send_Get_Webhook_Request(jenkins_url, gpcafile):
    #NB. Original query string below. It seems impossible to parse and
    #reproduce query strings 100% accurately so the one below is given
    #in case the reproduced version is not "correct".
    # response = requests.get('https://$ARG1$/generic-webhook-trigger/invoke?token=$ARG2$')
    headers = {'webhookrequester': 'op5 event hanbler',}
    params = (('token', args.webhook_token),)
    response = requests.get(jenkins_url, headers=headers, params=params, verify=gpcafile)
    print(response)
    return

def Post_Webhook_Request_Json(jenkins_url, gpcafile):
    #NB. Original query string below. It seems impossible to parse and
    #reproduce query strings 100% accurately so the one below is given
    #in case the reproduced version is not "correct".
    # response = requests.post('http://localhost:8080/jenkins/generic-webhook-trigger/invoke?token=TOKEN_HERE', headers=headers, data=data)
    headers = {'Content-Type': 'application/json', 'webhookrequester': 'op5 event hanbler',}
    params = (('token', args.webhook_token),)
    data = args.webhook_json
    response = requests.post(jenkins_url, headers=headers, params=params, data=data, verify=gpcafile)
    return

def main():

    parser = argparse.ArgumentParser(description="This event handler will call the jenkins Generic Webhook Trigger Plugin.")
 
    parser.add_argument("--service_state", type=str, default='CRITICAL', help='The service state, use $SERVICESTATE$')
    parser.add_argument("--service_state_type", type=str, default = 'SOFT', help='The type of the state, use $SERVICESTATETYPE$')
    parser.add_argument("--service_attempt", type=int, default=1, help='Current attempt number, $SERVICEATTEMPT$')
    parser.add_argument("--jenkins_host_name", type=str, default='jenkins.apps.gl3/jenkins', help='The jenkins server host name.')
    parser.add_argument("--webhook_token", type=str, default='BQopsTestBasic', help='The generic webhook trigger token.')
    parser.add_argument("--webhook_json", type=str, default=None, help='The generic webhook trigger json.')

    global args
    args = parser.parse_args()
    
    jenkins_url = 'https://'+args.jenkins_host_name+'/generic-webhook-trigger/invoke'
    gpcafile = '/etc/ssl/certs/GreenpeaceGlobalAuthenticationandEncryptionRootCA2010.pem'
    
    if args.service_attempt == 1 and args.service_state == "CRITICAL" and args.service_state_type == "SOFT":
        if args.webhook_json == None:
            Send_Get_Webhook_Request(jenkins_url, gpcafile)
        else:
            Post_Webhook_Request_Json(jenkins_url, gpcafile)
            
    sys.exit(0)
    
if __name__ == "__main__":
    main()