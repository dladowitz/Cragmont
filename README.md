# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...



### Running Development
You need to setup a Stripe Webhook

In the terminal
`> stripe listen --forward-to localhost:3000/stripe/webhooks`
`Your webhook signing secret is whsec_5967cf8b869a0d87fe90543fd0a4fd00ec80d0da01f1efb0c836bc4f35821874`

Update the .env.development file
`STRIPE_WEBHOOK_SECRET=whsec_5967cf8b869a0d87fe90543fd0a4fd00ec80d0da01f1efb0c836bc4f35821874`


Start Rails Server in the terminal
`> rails s`