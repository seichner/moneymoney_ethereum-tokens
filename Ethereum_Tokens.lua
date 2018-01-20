-- Inofficial Ethereum Extension for MoneyMoney
-- Uses the EthPlorer API to retrieve ETH/ERC20 balances
-- Uses the CryptoCompare-API to retrieve prices
-- Returns the asses as MoneyMoney-securities

-- inspired by https://github.com/Jacubeit/Ethereum-MoneyMoney (Johannes Jacubeit)

--
-- Username: Ethereum Adresses, comma seperated
-- Password: (anything)

-- MIT License
-- Copyright (c) 2018 Sebastian Eichner (seichner)

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.


local serviceName = "Ethereum+ERC20"

WebBanking{
  version = 0.1,
  description = "Allows to add your Ethereum addresses to MoneyMoney (addresses as usernme, comma seperated). Supports ETH and all ERC20-tokens (like EOS, OMG, DataCoin,...)",
  services= { serviceName }
}


local ethAddresses
local connection = Connection()
local currency = "EUR" -- fixme: make dynamic if MM enables input field

function SupportsBank (protocol, bankCode)
  return protocol == ProtocolWebBanking and bankCode == serviceName
end

function InitializeSession (protocol, bankCode, username, username2, password, username3)
  ethAddresses = username:gsub("%s+", "")
end

function ListAccounts (knownAccounts)
  local account = {
    name = "Ethereum",
    accountNumber = "Crypto Asset Ethereum",
    currency = currency,
    portfolio = true,
    type = "AccountTypePortfolio"
  }

  return {account}
end

function RefreshAccount (account, since)
  local securities = {}
  local address

  for address in string.gmatch(ethAddresses, '([^,]+)') do
    local balances = requestBalancesForEthAddress(address)
    for i, balance in ipairs(balances) do
      local price = requestPrice(balance.symbol)[currency]
      securities[#securities+1] = {
        name = balance["name"] .. " (" .. address .. ")",
        currency = nil,
        market = "cryptocompare",
        quantity = balance["quantity"],
        price = price,
      }
    end
  end  
  return {securities = securities}
end

function EndSession ()
end


-- Query Functions
function requestPrice(cryptocurrency)
  local content = connection:request("GET", cryptocompareRequestUrl(cryptocurrency), {})
  local json = JSON(content)

  return json:dictionary()
end

function requestBalancesForEthAddress(ethAddress)
  local content = connection:request("GET", ethplorerRequestUrl(ethAddress), {})
  local json = JSON(content)

  -- {  
  --  "address":"0x856e8d574de23...",
  --  "ETH":{  
  --    "balance":0.01,
  --    "totalIn":0.01,
  --    "totalOut":0
  --  },
  --  "countTxs":1,
  --  "tokens":[  
  --    {  
  --      "tokenInfo":{  
  --        "address":"0x0cf0ee63788a0849fe5297f3407f701e122cc023",
  --        "name":"DATAcoin",
  --        "decimals":18,
  --        "symbol":"DATA",
  --        "totalSupply":"987154514000000000000000000",
  --        "owner":"0x1bb7804d12fa4f70ab63d0bbe8cb0b1992694338",
  --        "lastUpdated":1515143375,
  --        "totalIn":2.165e+26,
  --        "totalOut":2.165e+26,
  --        "issuancesCount":0,
  --        "holdersCount":435307,
  --        "price":false
  --      },
  --      "balance":3.143e+21,
  --      "totalIn":0,
  --      "totalOut":0
  --    }
  --  ]
  --}
  
  local res = json:dictionary()

  -- start with ETH quantity
  local balances = {
    {
      name = "ETH",
      quantity = res["ETH"]["balance"],
      symbol = "ETH"
    }
  }
  
  -- add all ERC20 tokens
  for i, token in ipairs(res["tokens"]) do
    tokenDecimals = token["tokenInfo"]["decimals"]
    rawQuantity = token["balance"]
    quantity = rawQuantity / 10^tokenDecimals
    balances[#balances+1] = {
      name = token["tokenInfo"]["name"],
      quantity = quantity,
      symbol = token["tokenInfo"]["symbol"],
      }
  end

  return balances
end


-- Helper Functions
function cryptocompareRequestUrl(cryptocurrency)
  return "https://min-api.cryptocompare.com/data/price?fsym=" .. cryptocurrency .. "&tsyms=EUR,USD"
end

function ethplorerRequestUrl(ethAddress)
  local ethplorerRoot = "https://api.ethplorer.io/getAddressInfo/"
  local apiKey = "?apiKey=freekey"

  return ethplorerRoot .. ethAddress .. apiKey
end

