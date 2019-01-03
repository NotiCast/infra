AWS infrastructure Terraform and Ansible automation

**Note:** This repository contains Git submodules and should be recursively
cloned. This can be done by passing the `--recursive` flag to Git.

**Note:** If you do not have a copy of the lambda ZIP file compatible with
AWS Lambda servers, you need to at least clone the repository and run
`make message_lambda.zip`, which should then be copyable to another system.

### Dependencies

- Terraform
- Ansible
- `jq`
- Python 3.6 (or run Make with `PYTHON_VERSION=python3.<whatever>`)
  - Also requires `virtualenv`

### Configuring AWS Credentials


The contents of `$HOME/.aws/credentials` should look like:

```
[default]
aws_access_key_id = AKL0R3M1P5UMD0L0R
aws_secret_access_key = SiTAmETConSECtetUrADiPISCing
```

These can be retrieved from your IAM account. You can test them with the `aws`
command line utility.

### Running

To set up DNS nameservers:

```bash
make setup-pre
```

To set up the infrastructure:

```bash
make
make deploy
```

`terraform apply` will not be included in the default Makefile target because
of potential issues with the current Terraform state, and should be looked over
before applying the state.

---

A master API key, as well as the API URL, can be acquired from the Terraform
output variables by running: `terraform output`

## Routes

#### `/send_message` [POST]

Queue messages for NotiCast devices

**Request Type:** JSON

- `message: string` - Required - Message to send to devices
- `voice_id: string` - Optional - AWS Polly VoiceID to use
- `testing: bool` - Optional - Don't send out messages to the devices
  - Only works in `test`/`dev` stages

**Response Type:** JSON

- `message: string` - Earlier sent string
- `uri: string`: - URI of MP3 file containing `message` run through Polly
