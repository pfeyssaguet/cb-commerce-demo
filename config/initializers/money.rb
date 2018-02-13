currency_settings = [
  {
    iso_code:        'BTC',
    name:            'Bitcoin',
    symbol:          'BTC',
    subunit:         'satoshi',
    subunit_to_unit: 100_000_000,
    symbol_first:    false,
    decimal_mark:    '.',
    thousands_separator: ',',
    smallest_denomination: 1,
    separator:       '.',
    delimiter:       ','
  },
  {
    iso_code:        'LTC',
    name:            'Litecoin',
    symbol:          'LTC',
    subunit:         'satoshi',
    subunit_to_unit: 100_000_000,
    symbol_first:    false,
    decimal_mark:    '.',
    thousands_separator: ',',
    smallest_denomination: 1,
    separator:       '.',
    delimiter:       ','
  },
  {
    iso_code:        'ETH',
    name:            'Ethereum',
    symbol:          'ETH',
    subunit:         'gwei',
    subunit_to_unit: 1_000_000_000,
    symbol_first:    false,
    decimal_mark:    '.',
    thousands_separator: ',',
    smallest_denomination: 1000,
    separator:       '.',
    delimiter:       ','
  },
  {
    iso_code:        'BCH',
    name:            'Bitcoin Cash',
    symbol:          'BCH',
    subunit:         'satoshi',
    subunit_to_unit: 100_000_000,
    symbol_first:    false,
    decimal_mark:    '.',
    thousands_separator: ',',
    smallest_denomination: 1,
    separator:       '.',
    delimiter:       ','
  }
]

currency_settings.each { |setting| Money::Currency.register(setting) }
Money.default_currency = Money::Currency.new('USD')

# Ensure we don't silently convert from one currency to another
Money.disallow_currency_conversion!

class Money
  # Returns a multiple of smallest_denomination
  def round
    amount = round_to_nearest_cash_value
    Money.new(amount, currency)
  end
end
