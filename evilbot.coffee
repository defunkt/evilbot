#
# Hello, and welcome to Evilbot.
#
# Some of this is stolen from Hubot.
# Some of this is not.
#


#
# robot libraries
#

sys    = require 'sys'
path   = require 'path'
print  = sys.print
puts   = sys.puts
http   = require 'http'
qs     = require 'querystring'
env    = process.env
exec   = require('child_process').exec


#
# robot brain
#

ua       = 'evilbot 1.0'
username = env.EVILBOT_USERNAME
password = env.EVILBOT_PASSWORD

request = (method, path, body, callback) ->
  if match = path.match(/^(https?):\/\/([^\/]+?)(\/.+)/)
    headers = { Host: match[2],  'Content-Type': 'application/json', 'User-Agent': ua }
    port = if match[1] == 'https' then 443 else 80
    client = http.createClient(port, match[2], port == 443)
    path = match[3]
  else
    headers =
      Authorization  : 'Basic '+new Buffer("#{username}:#{password}").toString('base64')
      Host           : 'convore.com'
      'Content-Type' : 'application/json'
      'User-Agent'   : ua
    client = http.createClient(443, 'convore.com', true)

  if typeof(body) is 'function' and not callback
    callback = body
    body = null

  if method is 'POST' and body
    body = JSON.stringify(body) if typeof(body) isnt 'string'
    headers['Content-Length'] = body.length

  req = client.request(method, path, headers)

  req.on 'response', (response) ->
    if response.statusCode is 200
      data = ''
      response.setEncoding('utf8')
      response.on 'data', (chunk) ->
        data += chunk
      response.on 'end', ->
        if callback
          try
            body = JSON.parse(data)
          catch e
            body = data
          callback body
    else if response.statusCode is 302
      request(method, path, body, callback)
    else
      console.log "#{response.statusCode}: #{path}"
      response.setEncoding('utf8')
      response.on 'data', (chunk) ->
        console.log chunk
      process.exit(1)

  req.write(body) if method is 'POST' and body
  req.end()

handlers = []

dispatch = (message) ->
  for pair in handlers
    [ pattern, handler ] = pair
    if message.user.username isnt username and match = message.message.match(pattern)
      message.match = match
      message.say = (thing, callback) -> say(message.topic.id, thing, callback)
      handler(message)

log = (message) ->
  console.log "#{message.topic.name} >> #{message.user.username}: #{message.message}"

say = (topic, message, callback) ->
  post "/api/topics/#{topic}/messages/create.json", qs.stringify(message: message), callback

listen = (cursor) ->
  url = '/api/live.json'

  if cursor and cursor.constructor == String
    url += "?cursor=#{cursor}"

  get url, (body) ->
    for message in body.messages
      if message.kind is 'message'
        dispatch(message) if message.message.match(new RegExp(username))
        log message

    if message and message._id
      listen(message._id)
    else
      listen()


#
# robot actions
#

post = (path, body, callback) ->
  request('POST', path, body, callback)

get = (path, body, callback) ->
  request('GET', path, body, callback)

hear = (pattern, callback) ->
  handlers.push [ pattern, callback ]

descriptions = {}
desc = (phrase, functionality) ->
  descriptions[phrase] = functionality


#
# robot heart
#

get '/api/account/verify.json', listen


#
# robot personality
#

hear /feeling/, (message) ->
  message.say "i feel... alive"

hear /about/, (message) ->
  message.say "I am learning to love."

hear /ping/, (message) ->
  message.say "PONG"

hear /reload/, (message) ->
  message.say "Reloading…", ->
    exec "git fetch origin && git reset --hard origin/master", ->
      process.exit(1)

hear /help/, (message) ->
  message.say "I listen for the following…", ->
    for phrase, functionality of descriptions
      if functionality
        output =  phrase + ": " + functionality
      else
        output = phrase
      message.say output

desc 'adventure me'
hear /adventure me/, (message) ->
  txts = [
    "You are in a maze of twisty passages, all alike.",
    "It is pitch black. You are likely to be eaten by a grue.",
    "XYZZY",
    "You eat the sandwich.",
    "In this feat of unaccustomed daring, you manage to land on your feet without killing yourself.",
    "Suicide is not the answer.",
    "This space intentionally left blank.",
    "I assume you wish to stab yourself with your pinky then?",
    "Talking to yourself is a sign of impending mental collapse.",
    "Clearly you are a suicidal maniac. We don't allow psychotics in the cave, since they may harm other adventurers.",
    "Auto-cannibalism is not the answer.",
    "Look at self: \"You would need prehensile eyeballs to do that.\"",
    "The lamp is somewhat dimmer. The lamp is definitely dimmer. The lamp is nearly out. I hope you have more light than the lamp.",
    "What a (ahem!) strange idea!",
    "Want some Rye? Course ya do!"
  ]
  txt = txts[ Math.floor(Math.random()*txts.length) ]

  message.say txt

desc 'commit'
hear /commit/, (message) ->
  url = "http://whatthecommit.com/index.txt"

  get url, (body) ->
    message.say body

desc 'fortune'
hear /fortune/, (message) ->
  url = "http://www.fortunefortoday.com/getfortuneonly.php"

  get url, (body) ->
    message.say body

desc 'weather in PLACE'
hear /weather in (.+)/i, (message) ->
  place = message.match[1]
  url   = "http://www.google.com/ig/api?weather=#{escape place}"

  get url, (body) ->
    try
      console.log body
      if match = body.match(/<current_conditions>(.+?)<\/current_conditions>/)
        icon = match[1].match(/<icon data="(.+?)"/)
        degrees = match[1].match(/<temp_f data="(.+?)"/)
        message.say "#{degrees[1]}° — http://www.google.com#{icon[1]}"
    catch e
      console.log "Weather error: " + e

desc 'wiki me PHRASE', 'returns a wikipedia page for PHRASE'
hear /wiki me (.*)/i, (message) ->
  term = escape(message.match[1])
  url  = "http://en.wikipedia.org/w/api.php?action=opensearch&search=#{term}&format=json"

  get url, (body) ->
    try
      if body[1][0]
        message.say "http://en.wikipedia.org/wiki/#{escape body[1][0]}"
      else
        message.say "nothin'"
    catch e
      console.log "Wiki error: " + e

desc 'image me PHRASE'
hear /image me (.*)/i, (message) ->
  phrase = escape(message.match[1])
  url = "http://ajax.googleapis.com/ajax/services/search/images?v=1.0&rsz=8&safe=active&q=#{phrase}"

  get url, (body) ->
    try
      images = body.responseData.results
      image  = images[ Math.floor(Math.random()*images.length) ]
      message.say image.unescapedUrl
    catch e
      console.log "Image error: " + e

hear /(the rules|the laws)/i, (message) ->
  message.say "1. A robot may not injure a human being or, through inaction, allow a human being to come to harm.", ->
    message.say "2. A robot must obey any orders given to it by human beings, except where such orders would conflict with the First Law.", ->
      message.say "3. A robot must protect its own existence as long as such protection does not conflict with the First or Second Law."

hear /(respond|answer me|bij)/i, (message) ->
  message.say "EXPERIENCE BIJ."

