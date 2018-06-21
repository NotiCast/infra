# infra
AWS infrastructure setup scripts

To set up DNS nameservers:

```bash
sh setup.sh --pre
```

To set up the infrastructure:

```bash
sh setup.sh
terraform apply terraform.apply
```

`terraform apply` will not be included in the setup script as it can cause
issues with the current Terraform state, and should be looked over before
applying the state.

---

A master API key, as well as the API URL, can be acquired from the Terraform
output variables by running: `terraform apply`

## Routes

#### `/send_message` [POST]

Queue messages for NotiCast devices

**Request Type:** JSON

- `message: string` - Required - Message to send to devices
- `voiceid: string` - Optional - AWS Polly VoiceID to use

**Response Type:** JSON

- `message: string` - Earlier sent string
- `uri: string`: - URI of MP3 file containing `message` run through Polly
