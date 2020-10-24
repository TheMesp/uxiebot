# T.ournament bot
# David "Mesp" Loewen

require 'discordrb'
require 'json'
require 'pp'
require 'fileutils'

# Constants used by the bot for initialization
require_relative 'secrets.rb'
require_relative 'data.rb'

@bot = Discordrb::Commands::CommandBot.new token: DISCORD_TOKEN, client_id: DISCORD_CLIENT, prefix: '!'

require_relative 'tourney.rb'
require_relative 'marketplace.rb'

# initial setup
@bot.run(true)
puts "bot active"
@bot.set_user_permission(116674993424826375, 8)
@bot.set_user_permission(666433398482534404, 8)

@bot.join

