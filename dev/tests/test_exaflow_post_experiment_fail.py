import pytest
import json

import requests


all_error_cases = [
    (
        "Invalid parameter name",
        {
            "algorithm": {
                "name": "logistic_regression",
                "parameters": [
                    {
                        "name": "xyz",
                        "value": "rightppplanumpolare,righthippocampus,lefthippocampus,rightamygdala,leftamygdala",
                    },
                    {"name": "y", "value": "alzheimerbroadcategory"},
                    {"name": "pathology", "value": "dementia"},
                    {"name": "dataset", "value": "edsd,ppmi"},
                    {"name": "filter", "value": ""},
                    {"name": "positive_class", "value": "AD,CN"},
                ],
            },
            "name": "Exaflow Invalid parameter name",
        }
    ),
    (
        "Invalid algorithm name",
        {
            "algorithm": {
                "name": "LOGISTIC_REGRESSION",
                "parameters": [
                    {
                        "name": "xyz",
                        "value": "rightppplanumpolare,righthippocampus,lefthippocampus,rightamygdala,leftamygdala",
                    },
                    {"name": "y", "value": "alzheimerbroadcategory"},
                    {"name": "pathology", "value": "dementia"},
                    {"name": "dataset", "value": "edsd,ppmi"},
                    {"name": "filter", "value": ""},
                    {"name": "positive_class", "value": "AD,CN"},
                ],
            },
            "name": "Exaflow Invalid parameter name",
        }
    ),
    (
        "Invalid parameter value",
        {
            "algorithm": {
                "name": "logistic_regression",
                "parameters": [
                    {"name": "x", "value": "xyz"},
                    {"name": "y", "value": "alzheimerbroadcategory"},
                    {"name": "pathology", "value": "dementia"},
                    {"name": "dataset", "value": "edsd,ppmi"},
                    {"name": "filter", "value": ""},
                    {"name": "positive_class", "value": "AD,CN"},
                ],
            },
            "name": "Exaflow Invalid parameter value",
        }
    ),
]

@pytest.mark.parametrize("test_case,test_input", all_error_cases)
def test_post_request_exaflow(test_case, test_input):
    url = "http://127.0.0.1:8080/services/experiments"

    request_json = json.dumps(test_input)

    headers = {"Content-type": "application/json", "Accept": "application/json"}
    response = requests.post(url, data=request_json, headers=headers)
    assert response.status_code == 400
    error = json.loads(response.text)
    assert error["title"] == "Bad Request"
    assert error["detail"] == "Failed to read request"
    assert error["instance"] == "/services/experiments"


def test_post_request_exaflow_invalid_parameters_type():
    url = "http://127.0.0.1:8080/services/experiments"

    request_json = json.dumps(
        {
            "algorithm": {
                "name": "LOGISTIC_REGRESSION",
                "parameters": "xyz",
            },
            "name": "Error_Logistic_Regression",
        }
    )

    headers = {"Content-type": "application/json", "Accept": "application/json"}
    response = requests.post(url, data=request_json, headers=headers)
    assert response.status_code == 400
    error = json.loads(response.text)
    assert error["title"] == "Bad Request"
    assert error["detail"] == "Failed to read request"
    assert error["instance"] == "/services/experiments"
