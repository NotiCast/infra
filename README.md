# infra
AWS infrastructure setup scripts

## Routes

#### `/send_message` [POST]

Queue messages for NotiCast devices

**Request Type:** JSON

- `message: string` - Required - Message to send to devices
- `voiceid: string` - Optional - AWS Polly VoiceID to use

**Response Type:** JSON

- `message: string` - Earlier sent string
- `uri: string`: - URI of MP3 file containing `message` run through Polly
