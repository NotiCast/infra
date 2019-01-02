AWS infrastructure Terraform and Ansible automation

**Note:** If you do not have a copy of the lambda ZIP file compatible with
AWS Lambda servers, you need to at least clone the repository and run
`make message_lambda.zip`, which should then be copyable to another system.

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
