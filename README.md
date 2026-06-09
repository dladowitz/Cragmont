### Cragmont Climbng Club




### Running Development
You need to setup a Stripe Webhook

In the terminal
`> stripe listen --forward-to localhost:3000/stripe/webhooks`
`Your webhook signing secret is whsec_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`

Update the .env.development file
`STRIPE_WEBHOOK_SECRET=whsec_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`


Start Rails Server in the terminal
`> rails s`
