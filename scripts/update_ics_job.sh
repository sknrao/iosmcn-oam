#!/bin/bash

#  ============LICENSE_START===============================================
#  Copyright (C) 2023 Nordix Foundation. All rights reserved.
#  ========================================================================
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#  ============LICENSE_END=================================================
#

# args: <ics-ip> <job-id> <job-index-suffix> [<access-token>]
# job file shall exist in file "".job.json"
update_ics_job() {

    if [ -n "$1" ]; then
    # Assign the input parameter to a local variable
    ICS_ADDRESS="$1"
        echo "ICS address (IP:PORT): $ICS_ADDRESS"
    else
        echo "ICS address does not exist."
        exit 1
    fi
    JOB=$(<.job.json)
    echo $JOB
    retcode=1
    echo "Updating job $2"
    while [ $retcode -ne 0 ]; do
        if [ -z "$3" ]; then
            __bearer=""
        else
            __bearer="Authorization: Bearer $TOKEN"
        fi
        STAT=$(curl -s -X PUT -w '%{http_code}' -H accept:application/json -H Content-Type:application/json http://$ICS_ADDRESS/data-consumer/v1/info-jobs/$2 --data-binary @.job.json -H "$__bearer" )
        retcode=$?
        echo "curl return code: $retcode"
        if [ $retcode -eq 0 ]; then
            status=${STAT:${#STAT}-3}
            echo "http status code: "$status
            if [ "$status" == "200" ]; then
                echo "Job created ok"
            elif [ "$status" == "201" ]; then
                echo "Job created ok"
            else
                retcode=1
            fi
        fi
        sleep 1
    done
}
