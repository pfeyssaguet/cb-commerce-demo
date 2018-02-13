require 'sinatra'
require 'money'
require 'httparty'
require 'inline/erb'
require 'pry'
require 'sinatra-initializers'

# replace with your actual API key
API_KEY = ENV['API_KEY']
COMMERCE_BASE_URL = 'https://commerce.coinbase.com'
# replace with your Webhook Shared Secret in the /settings "Webhook Subscriptions" Section
# Click "Show shared secret" after adding a webhook subscription
COMMERCE_SHARED_SECRET = ENV['COMMERCE_SHARED_SECRET']

class Book
  attr_accessor :title, :price, :description, :slug, :product_id

  def initialize(title, description, price, slug)
    @title =  title
    @description = description
    @price = price
    @slug = slug
  end

  def checkout_link
    return unless @product_id
    "#{COMMERCE_BASE_URL}/products/#{@product_id}"
  end

  def to_query
    {
      name: title,
      local_price: { amount: price.amount, currency: price.currency.iso_code },
      donation: false,
      description: description,
      enabled_customer_metadata: [:name, :email]
    }
  end

  # hack since we don't have a real database
  def find_by(product_id)
    @@books.detect{|book| book.product_id == product_id}
  end
end

class Order
  attr_accessor :charge_id, :product_id, :customer_name, :customer_email,
   :confirmed_at, :order_code, :crypto_value

  def self.from_payload(request_payload)
    new_order = self.new
    charge_data = request_payload['event']['data']
    new_order.product_id = charge_data['product']['id']
    new_order.customer_name = charge_data['metadata']['name']
    new_order.customer_email = charge_data['metadata']['email']
    new_order.charge_id = charge_data['id']
    new_order.order_code = charge_data['order_code']
    new_order.confirmed_at = DateTime.parse(charge_data['confirmed_at'])
    new_order.crypto_value = Money.new(
      charge_data['primary_payment_value']['amount'],
      charge_data['primary_payment_value']['currency'])

    new_order
  end

  def fulfill
    # implement logic for fulfilling order here!
    # for example, emailing the PDF of the book to the customer
  end

  def book
    Book.find_by(product_id)
  end
end


class CoinbaseCommerce
  include HTTParty
  base_uri 'https://api-commerce.coinbase.com'

  def initialize
    @headers = {
      'X-CC-Api-Key': API_KEY,
      'Content-Type': 'application/json'
    }
  end

  def create_product(book)
    query = book.to_query
    response = self.class.post('/products', query: query, headers: @headers)
  end

  def verify_payload(payload_hash, sha256_header)
    sha256_header === OpenSSL::HMAC.hexdigest('SHA256', @shared_secret, JSON.dump(payload_hash))
  end

end


register Sinatra::Initializers

configure do
  I18n.available_locales = [:en]
  @@books = [
    Book.new(
      'Ethereal Ethereum',
      'A book to learn about the heavenly properties of Ethereum',
      Money.new(10, 'USD'),
      'ethereal_ethereum'),
    Book.new(
      'Litecoin Lite: An Introduction',
      'Learn the basics of Litecoin',
      Money.new(8, 'USD'),
      'litecoin_lite'),
    Book.new(
      'Rippling Ripple',
      'Learn how Ripple works',
      Money.new(2, 'USD'),
      'rippling_ripple'),
  ]

  @@orders = []
end

####################### ROUTING ############################

get '/' do
  erb :bookstore, locals: { books: @@books }
end

post '/create_products' do
  coinbase_commerce = CoinbaseCommerce.new
  @@books.map do |book|
    response = coinbase_commerce.create_product(book)
    book.product_id = JSON.parse(response.body)['data']['id'] if response.code == 201
  end
  redirect '/'
end

=begin
  Use ngrok (ngrok.com) to run this app locally. Whitelist the https ngrok URL in /settings,
  "Webhook Subscriptions" section. Don't forget to add the /deliver_book to the ngrok URL since
  that is the route we define below.
=end
post '/deliver_book' do
  encrypted_payload = request.env['HTTP_X_WEBHOOK_SHA256_HMAC']
  request.body.rewind
  request_payload = JSON.parse(request.body.read)

  if CoinbaseCommerce.sha256_hmac(request_payload) === encrypted_payload
    status 204 #successful request with no body content
  else
    status 503 # sender was NOT Coinbase Commerce; do not trust!
  end

  case request_payload['event']['type']
  # customer begins checkout
  when "charge::created"
    # WRITE CODE HERE for Charge Creation

  # customer's payment has been confirmed on the blockchain
  when "charge::completed"
    order = Order.from_payload(request_payload)
    order.fulfill
    @@orders << order

  # customer failed to pay because no payment detected or underpayment
  when "charge::failed"
  end
end

get '/orders' do
  erb :orders, locals: { orders: @@orders }
end

__END__

@@ layout
<html>
  <head>
    <title>Coinbase Commerce API Demo</title>
    <meta charset="utf-8" />
    <script src="http://ajax.googleapis.com/ajax/libs/jquery/1/jquery.min.js"></script>
  </head>
  <body><%= yield %></body>
</html>

@@ bookstore
<h1>Indie Online Book Store</h1>
<h2>Demo of Coinbase Commerce API</h2>
<ol>
  <% books.each do |book| %>
    <li>
      <h3><%= book.title %></h3>
      <div><%= book.description %></div>
      <div>Price: <%= book.price.format %></div>
      <% if book.checkout_link %>
        Checkout link: <a href="<%= book.checkout_link %>" target="_blank">Buy with Coinbase</a>
        <div>
          Modal:
          <div>
          <a class="buy-with-crypto" href="<%= book.checkout_link %>">
              <span>Buy with Crypto</span>
            </a>
            <script src="https://commerce.coinbase.com/v1/checkout.js"></script>
          </div>
        </div>
      <% end %>
    </li>
  <% end %>
</ol>

Create products in Coinbase Commerce for each book!
<form action='/create_products' method="post">
  <input type="submit">
</form>

@@ orders
<h1>Orders from Coinbase Commerce</h1>
<h2>Demo of Coinbase Commerce API</h2>
<ol>
  <% orders.each do |order| %>
    <li>
      <h3><%= order.order_code %> Order for <%= order.book.name %></h3>
      <div>Customer paid <%= order.crypto_value.format %></div>
      <div>Payment Confirmed: <%= order.confirmed_at.strftime('%d %b %Y %l:%M %p') %></div>
      <div>USD Book Price: <%= book.price.format %></div>
      <div>Customer <%= order.customer_name %></div>
      <div>Customer Email <%= order.customer_email %></div>
    </li>
  <% end %>
</ol>

