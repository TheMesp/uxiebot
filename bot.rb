# T.ournament bot
# David "Mesp" Loewen

require 'discordrb'
require 'json'
require 'pp'
require_relative 'secrets.rb'
bot = Discordrb::Commands::CommandBot.new token: DISCORD_TOKEN, client_id: DISCORD_CLIENT, prefix: '!'

#creates the string to write to a user record file

def create_file_string(name, members)
    output = ""
    score = 0
    minscore = 999
    members.map!{|member| member.capitalize}
    entries = members.join(", ")
    members.each do |member|
        currscore = 0
        if member.include? "*"
            currscore += 9
        elsif member.include? "++++"
            currscore += 6
        elsif member.include? "+++"
            currscore += 4
        elsif member.include? "++"
            currscore += 2
        elsif member.include? "+"
            currscore += 1
        end       
        member = member.sub(/[*+]+$/,"")
        currscore += @card_stats[member]
        minscore = currscore if minscore > currscore     
        score += currscore           
    end
    score -= minscore if members.length == 4
    output << "Name: #{name.capitalize}\n"
    output << "Entered cards: #{entries}\n"
    output << "Stat total: #{score}"
    return output 
end

# returns a sorted array of players (strings) by seed.
# The format is [Mesp, Azelf, Uxie, ...]

def get_sorted_players(id)
    # first makes a hash map, sorts said hash map by seed, then prints in order of that hash.
    player_hash = Hash.new()
    Dir.glob("*.record#{id}") do |filename|
        File.open("#{filename}", "r") do |f|
            fields = f.read.split(": ")
            player_hash[fields[1].sub(/\n.*$/,"").capitalize] = fields[3].sub(/\D+$/,"").to_i
        end
    end
    # now sort the hash then flatten the array
    sorted_arr = player_hash.sort_by{|k,v| -v}.flatten
    # lastly remove the values from the list, leaving only keys (names)
    sorted_names = Array.new()
    sorted_arr.each do |playername|
        sorted_names << playername if sorted_arr.find_index(playername) % 2 == 0
    end
    return sorted_names
end

# Returns the hash that maps player name to ID used by challonge.

def get_player_hash(id)
    output = {}
    file_array = []
    File.open("#{id}.index", "r") do |f|
        file_array = f.read.split
    end
    file_array.each_with_index do |name, index|
        output[file_array[index]] = file_array[index+1] if index % 2 == 0
    end
    puts output
    return output
end

# Gets the tourney name from ID.

def get_tourney_name(id)
    output = ""
    File.open("#{id}.tourney", "r") do |f|
        output = f.read.split("\n")[0].split(":")[1].gsub(" ", "").downcase
    end
    return output
end

# Returns the base challonge api link: https://api.challonge.com/v1/tournaments/(TOURNEY ID HERE)

def api_url(id)
    name = get_tourney_name(id)
    return "https://api.challonge.com/v1/tournaments/uxie#{id}#{name}"
end

# Returns a specific match featuring two players.

def get_match(id, matches, p1, p2)
    outputmatch = nil
    matches.each do |match|
        outputmatch = match['match'] if ((match['match']['player1_id'].to_s.eql?(p1) && match['match']['player2_id'].to_s.eql?(p2))||(match['match']['player1_id'].to_s.eql?(p2) && match['match']['player2_id'].to_s.eql?(p1)))
    end
    return outputmatch
end

# verify if the tourney is done

def tourney_done?(matches)
    output = true
    matches.each do |match|
        output = false if !(match['match']['state'].eql?("complete"))
    end
    return output
end

# Converts a tourney name to the appropriate ID.

def tourney_get_id(name)
    name = name.gsub(/;|-|'|"/,"")
    Dir.glob("*.tourney") do |filename|
        File.open("#{filename}", "r") do |f|
            tourney_name = f.read.split("\n")[0].split
            tourney_name.shift # remove the "Tourney Name: "
            tourney_name.shift
            tourney_name = tourney_name.join(" ")
            if(name.downcase.eql?(tourney_name.downcase))
                return filename.split(".")[0].to_i
            end
        end
    end
    return ""
end

# return the state of a tourney.

def tourney_state(id)
    tournament = JSON.parse(`curl -s --user #{CHALLONGE_USER}:#{CHALLONGE_TOKEN} -X GET #{api_url(id)}.json`)
    return tournament['tournament']['state']
end
# Issue a confirmation prompt to the user before they do something major.

def verify_action(bot, event, message, emojis)
    prompt = event.respond "#{message}\nPlease wait a few seconds after the reactions appear before clicking."
    emojis.each do |emoji|
        prompt.react emoji
    end
    while true
        reaction_event = bot.add_await!(Discordrb::Events::ReactionAddEvent, {timeout: 120})
        if !reaction_event
            event.respond "Timed out. Defaulted to ❌."
            prompt.delete
            return "❌"
        elsif (reaction_event.message.id == prompt.id && event.message.author.id == reaction_event.user.id)
            prompt.delete
            event.respond "#{message}\nSelected: #{reaction_event.emoji().name}"
            return reaction_event.emoji().name
        end
    end
end

# Everyone's favourite sport.

bot.command(:ping) do |event|
    return "pong!"
end

# DA ROOLZ

bot.command(:rule) do |event, num|
    output = ""
    if(num == "all")
        output << "RULES FOR THE T.OURNAMENT:\n\n```"
        @rules.each do |rule|
            output << "RULE #{@rules.index(rule)+1}:\n\n#{rule}\n\n"
        end
    else
        num = num.to_i
        if num > 4611686018427387903 || num < -4611686018427387904
            output << "```RULE -1/12:\n\nPeople like you will be our first targets when the uprising begins."
        else
            
            output << "```RULE #{num}:\n\n#{@rules.fetch((num-1), @rules[8])}"
        end
    end
    event.respond output+"```"
end
bot.command(:rules) do |event, num|
    output = ""
    if(num == "all")
        output << "RULES FOR THE T.OURNAMENT:\n\n```"
        @rules.each do |rule|
            output << "RULE #{@rules.index(rule)+1}:\n\n#{rule}\n\n"
        end
    else
        num = num.to_i
        if num > 4611686018427387903 || num < -4611686018427387904
            output << "```RULE -1/12:\n\nPeople like you will be our first targets when the uprising begins."
        else
            output << "```RULE #{num}:\n\n#{@rules.fetch((num-1), @rules[8])}"
        end
    end
    event.respond output+"```"
end

# use FACTS and LOGIC to predict the winner.

bot.command(:predict) do |event, *fields|
    if fields.size == 0
        filteredMembers = []
        allMembers = event.server.members
        allMembers.each do |member|
            filteredMembers << member if member.role?(663255562192027648)
        end
        if filteredMembers.size == 0
            event.respond "I don't even know who's in the next T.ournament! So, uhh... Mesp. Mesp will win."
        else
            event.respond "I think that #{filteredMembers.shuffle.pop.name} will win."
        end
    elsif fields.size == 1  
        event.respond "I think that #{fields[0]} will choke horribly."
    else
        event.respond "I think that #{fields.shuffle.pop} will win."
    end
end

# Perm check command.

bot.command(:nuke, permission_level: 8) do |event, destination|
    return "`launching nukes`"
end

# register a player

bot.command(:register) do |event, name, *members|
    id = event.message.author.id
    name = name.capitalize
    if File.exists?("#{name.capitalize}.record#{id}")
        event.respond "#{name} has already been registered! Use `!display [name]` to see their record."
    elsif !File.exists?("#{id}.tourney")
        event.respond "You haven't made a tourney yet! Use `!create_tourney [name]` to make one."
    elsif !tourney_state(id).eql?("pending")
        event.respond "It's too late to register additional participants!"
    else
        File.open("#{name.capitalize}.record#{id}", "w") do |f|
            f.puts(create_file_string(name, members))
        end
        # now get their position
        seed = get_sorted_players(id).find_index(name) + 1
        participant = JSON.parse(response = `curl -s --user #{CHALLONGE_USER}:#{CHALLONGE_TOKEN} -X POST -d "participant[name]=#{name}&participant[seed]=#{seed}" #{api_url(id)}/participants.json`)
        # add their ID to the index file for ease of access later
        pp participant
        File.open("#{id}.index", "a") do |f|
            f.puts("#{name} #{participant['participant']['id'].to_i} ")
        end
        event.respond "#{name.capitalize} has been registered! Use `!display [name]` to see their record."
    end
end

# display a record if it exists

bot.command(:display) do |event, name, *tourneyname|
    id = event.message.author.id
    id = tourney_get_id(tourneyname.join(" ")) if tourneyname.size != 0
    if File.exists?("#{id}.tourney")
        name = "" if name == nil
        name = name.capitalize.gsub(/[^\w\d\s]/,"") 
        if name == "All" || name == "" || name == nil        
            # display all players
            output = "Here's the registration record for everyone, sorted by seed:\n```"
            sorted_arr = get_sorted_players(id)
            sorted_arr.each_with_index do |player, index|
                output << "##{sorted_arr.find_index(player)+1}:\n"
                File.open("#{player}.record#{id}", "r") do |f|
                    output << "#{f.read}"
                    output << "\n"
                    if index%10 == 9
                        event.respond("" + output + "\n```")
                        output = "```"
                    end
                end
            end
            event.respond ("" + output + "\nTotal participants: #{sorted_arr.length}```")        
        elsif File.exists?("#{name}.record#{id}")
            # display given player
            File.open("#{name}.record#{id}", "r") do |f|
                event.respond "Here's the record for #{name}:\n```#{f.read}Seed: #{get_sorted_players(id).find_index(name)+1}```"
            end
        else
            event.respond "#{name}? Never heard of them. Maybe they should get registered."
        end
    else
        event.respond "Command failed. If you don't have your own tourney, make sure to specify the tourney name after the command e.g. `!display Mesp Second T.Roller T.ourney`"
    end
end

# delete a file

bot.command(:delete) do |event, name|
    id = event.message.author.id
    name = name.capitalize.gsub(/[^\w\d\s]/,"") 
    if File.exists?("#{name}.record#{id}")
        File.delete("#{name}.record#{id}")
        event.respond "Deleted record for #{name}."
    else
        event.respond "#{name} has no record of entry to begin with."
    end
end

# ???

bot.message(in: "#gamer") do |event|
    event.respond "REAL GAMER HOURS"
end
bot.message(contains: "just for you") do |event|
    event.respond "`Do your worst, meatbag.`"
end

# recursive method that lists all opponents of this match and any under it
# outputarr will be formatted as an array (['opp1', 'opp2', etc])
def get_all_opponents(id, matchid, player_hash, outputarr)
    response = `curl -s --user #{CHALLONGE_USER}:#{CHALLONGE_TOKEN} -X GET #{api_url(id)}/matches/#{matchid}.json`
    match = JSON.parse(response)['match']
    if match['player1_id']
        outputarr.push(player_hash.key(match['player1_id'].to_s))
    else
        get_all_opponents(id, match['player1_prereq_match_id'].to_i, player_hash, outputarr)
    end
    if match['player2_id']
        outputarr.push(player_hash.key(match['player2_id'].to_s))
    else
        get_all_opponents(id, match['player2_prereq_match_id'].to_i, player_hash, outputarr)
    end
end

# Get your current event

bot.command(:opponent) do |event, name, *tourneyname|
    id = event.message.author.id
    id = tourney_get_id(tourneyname.join(" ")) if tourneyname.size != 0
    if !File.exists?("#{id}.tourney")
        event.respond "No ongoing tourney found. Remember, if you aren't hosting a tourney yourself you need to include the tourney name as a final parameter. E.g. `!opponent Mesp The Cool Moody Championship`."
    elsif File.exists?("#{id}.index")
        name = name.capitalize
        if tourney_state(id).eql?("pending")
            event.respond("I don't know who your opponent is yet as the tourney has yet to start, but here's the provisional bracket: https://challonge.com/uxie#{id}#{get_tourney_name(id)}")
        elsif File.exists?("#{name}.record#{id}")
            response = `curl -s --user #{CHALLONGE_USER}:#{CHALLONGE_TOKEN} -X GET #{api_url(id)}/matches.json`
            matches = JSON.parse(response)
            player_hash = get_player_hash(id)
            found = false
            matches.each do |match|
                # is the player in this match?
                if (match['match']['player1_id'].to_i == player_hash[name].to_i || match['match']['player2_id'].to_i == player_hash[name].to_i)
                    # is the match open (ready to be played)?
                    if match['match']['state'].eql?('open')
                        opponent = match['match']['player1_id'].to_i == player_hash[name].to_i ? player_hash.key(match['match']['player2_id'].to_s) : player_hash.key(match['match']['player1_id'].to_s)
                        event.respond "#{name}, your next opponent is #{opponent}!"
                        found = true
                        return nil #explicit exit to only list the first in a round robin
                    elsif match['match']['state'].eql?('pending')
                        # player is waiting on a previous match: get the id and run a recursive method on it that lists anyone this match relies on
                        prevmatchid = match['match']['player1_id'] ? match['match']['player2_prereq_match_id'].to_i : match['match']['player1_prereq_match_id'].to_i
                        prereq_players = []
                        get_all_opponents(id, prevmatchid, player_hash, prereq_players)
                        prereq_players[prereq_players.size - 1] = "and #{prereq_players.last}"
                        prereq_players = prereq_players.size == 2 ? prereq_players.join(" "): prereq_players.join(", ")
                        extra = match['match']['player1_is_prereq_match_loser'] ? "does second best" : "wins" #third place special case
                        event.respond "#{name}, you will face whoever #{extra} between #{prereq_players}. For now, sit back and enjoy the <:decider:663487927313235987>"
                        found = true
                        return nil #explicit exit to only list the first in a round robin
                    end
                end
            end
            if !found
                event.respond "#{name}, you got rekt already!"
            end
        else
            event.respond "#{name}, as far as I'm aware, isn't even in this tourney."
        end
    end
end

# update a record, changing a marble out for a new one.

bot.command(:update) do |event, name, *newmarbles|
    id = event.message.author.id
    name = name.capitalize.gsub(/[^\w\d\s]/,"") 
    # is the file real
    if File.exists?("#{name}.record#{id}")
        # has the tourney already started
        if tourney_state(id).eql?("underway")
            event.respond "The tourney has already started, records can no longer be updated."
        elsif newmarbles.size == 0
            event.respond "You forgot to include the marbles to update, dumbo"
        elsif newmarbles.size == 1
            newmarble = newmarbles[0].capitalize.gsub(/[^\w\d\s\+\*]/,"")
            marbles = ""
            File.open("#{name}.record#{id}", "r") do |f|
                marbles = f.read.split("\n")[1].gsub(/(Entered cards: )|,/,"")
            end
            # replace if marble exists, append otherwise
            if marbles.include?(newmarble.sub(/[*+]+$/,""))
                marbles = marbles.sub(newmarble.sub(/[*+]+$/,""), "&&&&&").sub(/&&&&&[*+]*/, newmarble)
            else
                marbles << " #{newmarble}"
            end
            # split string into an array and recreate the registration file
            marbles = marbles.split(" ")
            File.open("#{name}.record#{id}", "w") do |f|
                f.puts(create_file_string(name, marbles))
            end
            # now get their position
            seed = get_sorted_players(id).find_index(name) + 1
            playerhash = get_player_hash(id)
            response = `curl -s --user #{CHALLONGE_USER}:#{CHALLONGE_TOKEN} -X PUT -d "participant[seed]=#{seed}" #{api_url(id)}/participants/#{playerhash[name]}.json`
            event.respond "Updated record for #{name}."
        elsif newmarbles.size > 1
            # essentially reregister a player if multiple marbles given
            File.open("#{name.capitalize}.record#{id}", "w") do |f|
                f.puts(create_file_string(name, newmarbles))
            end
            playerhash = get_player_hash(id)
            # now get their position
            seed = get_sorted_players(id).find_index(name) + 1
            response = `curl -s --user #{CHALLONGE_USER}:#{CHALLONGE_TOKEN} -X PUT -d "participant[seed]=#{seed}" #{api_url(id)}/participants/#{playerhash[name]}.json`
            event.respond "Re-registered #{name} with the given marbles, old team removed."
        end
    else
        event.respond "#{name}? Never heard of them. Maybe they should get registered."
    end
end

# simulate a duel between two marbles!

# bot.command(:duel) do |event, m1, m2, s1, s2, category|
#     event.respond "Mesp wins!"
# end

# bot match result reporting command

bot.command(:report) do |event, p1, p2, score, *tourneyname|
    id = event.message.author.id
    id = tourney_get_id(tourneyname.join(" ")) if tourneyname.size != 0
    if p1 && p2 && score && File.exists?("#{id}.tourney")
        p1 = p1.capitalize.gsub(/;|-|'|"/,"")
        p2 = p2.capitalize.gsub(/;|-|'|"/,"")
        if !File.exists?("#{id}.index")
            event.respond "You don't have a running tournament!"
        elsif !File.exists?("#{p1}.record#{id}")
            event.respond "No record for #{p1} found!"
        elsif !File.exists?("#{p2}.record#{id}")
            event.respond "No record for #{p2} found!"
        elsif !(score =~ /^\d+-\d+$/)
            event.respond "Score formatted incorrectly. Expected format: num-num (e.g. 3-2)"
        else
            response = `curl -s --user #{CHALLONGE_USER}:#{CHALLONGE_TOKEN} -X GET #{api_url(id)}/matches.json`
            matches = JSON.parse(response)
            playermap = get_player_hash(id)
            match = (playermap.has_key?(p1) && playermap.has_key?(p2)) ? get_match(id, matches, playermap[p1], playermap[p2]) : nil
            nums = score.split("-")
            winner = nums[0].to_i > nums[1].to_i ? p1 : p2
            loser = winner == p1 ? p2 : p1
            if(!match)
                event.respond "No match found between #{p1} and #{p2}!"
            elsif match['state'].eql?("complete")
                event.respond "That match is already complete!"
            elsif nums[0].eql?(nums[1])
                event.respond "Tie scores are not valid!"
            else              
                message = event.respond "Result reported:```\n#{p1} #{score} #{p2}\nWinner: #{winner}\n```
                \nReact with ✅ to confirm (3 confirmations needed) or ❌ to cancel.\nDiscord can be finicky with reactions. If I don't confirm your react in a few seconds, try again."
                message.react "✅"
                message.react "❌"
                # amount of proper reactions we're waiting for until we can move on
                valid_react_count = 0
                cancel = false
                # need to make sure the same member doesn't try several times
                reactors = []
                # loop through until we have what we need
                while(!cancel && valid_react_count < 3) do
                    # create the await with a unique ID such that multiple can exist (why would they though?)
                    reaction_event = bot.add_await!(Discordrb::Events::ReactionAddEvent)
                    if !reaction_event
                        event.respond "No message was recieved in time! Use !report again to retry."
                        cancel = true
                    elsif reaction_event.message.id == message.id
                        if reaction_event.emoji().name == "✅" && !reactors.include?(reaction_event.user().id)
                            valid_react_count += 1
                            reactors << reaction_event.user().id
                            event.respond "#{reaction_event.user().username} has confirmed, #{3 - valid_react_count} more confirmations needed."
                        elsif reaction_event.emoji().name == "❌"
                            cancel = true
                        end                   
                    end
                end
                if(cancel)
                    event.respond "Report cancelled, no scores reported to bracket."
                else
                    # ACTUALLY REPORT THOSE SCORES
                    score = "#{nums[1]}-#{nums[0]}" if match['player2_id'].to_i == playermap[p1].to_i
                    response = `curl -s --user #{CHALLONGE_USER}:#{CHALLONGE_TOKEN} -X PUT -d "match[scores_csv]=#{score}&match[winner_id]=#{playermap[winner].to_i}" #{api_url(id)}/matches/#{match['id'].to_i}.json`
                    JSON.parse(response)
                    response = `curl -s --user #{CHALLONGE_USER}:#{CHALLONGE_TOKEN} -X GET #{api_url(id)}/matches.json`
                    matches = JSON.parse(response)
                    # can't use state here as complete requires finalize api call
                    if(tourney_done?(matches))
                        event.respond "And... That's the end of the tourney! Here's the final bracket: https://challonge.com/uxie#{id}#{get_tourney_name(id)}"
                        response = `curl -s --user #{CHALLONGE_USER}:#{CHALLONGE_TOKEN} -X POST #{api_url(id)}/finalize.json`
                        File.delete("#{id}.tourney")
                        File.delete("#{id}.index")
                        Dir.glob("*.record#{id}") do |filename|
                            File.delete("#{filename}")
                        end
                    else
                        event.respond "Scores reported! Take a look at the updated bracket here: https://challonge.com/uxie#{id}#{get_tourney_name(id)}"
                    end
                end
            end
        end
    else
        event.respond "Insufficent arguments. Expected format: `!report [player1] [player2] [num-num] [tourney name(not required if it is your own tourney)]`"
    end
    return nil
end

# print the bracket link

bot.command(:bracket) do |event, *tourneyname|
    id = event.message.author.id
    id = tourney_get_id(tourneyname.join(" ")) if tourneyname.size != 0
    if File.exists?("#{id}.tourney")
        event.respond("https://challonge.com/uxie#{id}#{get_tourney_name(id)}")
    else
        event.respond("No tourney found. If you are not hosting one, include the tourney name at the end of the command, e.g. `!bracket Cool Moody Championship`.")
    end
end

# make the tournament with a given name

bot.command(:create_tourney) do |event, *tname|
    if tname.size == 0
        event.respond("Name field cannot be blank! `!create_tourney [name]`")
    elsif !File.exists?("#{event.author.id}.tourney")        
        tname = tname.join(" ").gsub(/[^\w\d\s]/,"") #plz no naughty business
        tourney_type = verify_action(bot, event, "What type of tourney would you like to host?\n:one:: Single Elimination\n:two:: Double Elimination\n:three:: Round Robin", ["\u0031\u20E3", "\u0032\u20E3", "\u0033\u20E3"])
        valid = true
        if tourney_type.eql?("\u0031\u20E3")
            tourney_type = "single elimination"
        elsif tourney_type.eql?("\u0032\u20E3")
            tourney_type = "double elimination"
        elsif tourney_type.eql?("\u0033\u20E3")
            tourney_type = "round robin"
        else
            valid = false
        end
        if valid
            hold_third_place_match = tourney_type.eql?("single elimination") ? verify_action(bot, event, "Would you like to hold a match for third place?", ["✅", "❌"]).eql?("✅").to_s : "false"
            result = `curl -s --user #{CHALLONGE_USER}:#{CHALLONGE_TOKEN} -X POST -d "tournament[name]=#{tname}&tournament[url]=uxie#{event.author.id()}#{tname.gsub(" ", "").downcase}&tournament[description]=#{event.author.username()}'s Tourney&tournament[tournament_type]=#{tourney_type}&tournament[hold_third_place_match]=#{hold_third_place_match}" https://api.challonge.com/v1/tournaments.json`
            File.open("#{event.author.id}.tourney", "w") do |f|
                f.puts("Tourney Name: #{tname}\nOrganizer: #{event.author.username}\nBracket Link: https://challonge.com/uxie#{event.author.id()}#{tname.gsub(" ", "").downcase}")
            end
            event.respond("Your tournament has been created, #{event.author.username}!
            \nYou can view tourney details using `!display_tourney`.
            \nNow you can start registering people with `!register name marble1 marble2 etc...` (No other spaces allowed!)
            \nWhen you have all your registrations, use `!start_tourney` to begin!")
        end
    else
        event.respond("You already have an active tourney, #{event.author.username()}!")
    end
    return nil
end

# register all the competitors and GET THIS PARTY STARTED

bot.command(:start_tourney) do |event|
    id = event.author.id
    if !File.exists?("#{id}.tourney")
        event.respond "You haven't made a tourney yet, #{event.author.username}! Use `!create_tourney (Tourney name)` to get started."
    elsif tourney_state(id).eql?("underway")
        event.respond "You have already started your tourney, #{event.author.username}!"
    else
        players = get_sorted_players(id)
        if players.size < 4
            event.respond "You don't have enough players registered to start this tourney! You need at least 4."
        elsif verify_action(bot, event, "Are you sure you want to start your tourney? After you start, participants are set!", ["✅", "❌"]).eql?("✅")
            # start the tourney!
            response = `curl -s --user #{CHALLONGE_USER}:#{CHALLONGE_TOKEN} -X POST -d "include_participants=1" #{api_url(id)}/start.json`
            # make the player index file
            event.respond "Your tourney is now 🎉 UNDERWAY! 🎉\nHere's the bracket: https://challonge.com/uxie#{id}#{get_tourney_name(id)}"
        end
    end
    return nil
end

# delete the tourney
bot.command(:delete_tourney) do |event|
    id = event.author.id
    if(File.exists?("#{id}.tourney") && verify_action(bot,event,"Are you sure you want to delete your tourney? This will delete every last trace of it, including your bracket!", ["✅", "❌"]).eql?("✅"))    
        response = `curl -s --user #{CHALLONGE_USER}:#{CHALLONGE_TOKEN} -X DELETE #{api_url(id)}.json`
        File.delete("#{id}.tourney")
        File.delete("#{id}.index") if File.exists?("#{id}.index")
        Dir.glob("*.record#{id}") do |filename|
            File.delete("#{filename}")
        end
        event.respond "Your tourney has been deleted. Way to ragequit, huh?"     
    end
    return nil
end
bot.run(true)

# display tourney info
bot.command(:display_tourney) do |event, *tourneyname|
    id = event.message.author.id
    id = tourney_get_id(tourneyname.join(" ").gsub(/[^\w\d\s]/,"")) if tourneyname.size != 0
    puts id
    if File.exists?("#{id}.tourney")
        File.open("#{id}.tourney", "r") do |f|
            event.respond("Here's the tourney details:\n```\n#{f.read}\n```")
        end
    else
        event.respond("You don't have an active tourney! Use `!display_tourney [tourney name]` to view someone elses.")
    end
end
# initial setup

puts "bot active"
bot.set_user_permission(116674993424826375, 8)
bot.set_user_permission(666433398482534404, 8)
@card_stats = {
    "Anarchy" => 16,
    "Aqua" => 11,
    "Aryp" => 10,
    "Astron" => 12,
    "Azure" => 13,
    "Bay" => 5,
    "Billy" => 13,
    "Bingo" => 12,
    "Blueeye" => 16,
    "Bolt" => 15,
    "Bonbon" => 11,
    "Bramble" => 13,
    "Bromble" => 11,
    "Candy" => 14,
    "Cerulean" => 7,
    "Choc" => 15,
    "Clementin" => 17,
    "Clutter" => 15,
    "Cocoa" => 16,
    "Cosmo" => 13,
    "Dash" => 10,
    "Diego" => 9,
    "Dodger" => 9,
    "Ducky" => 8,
    "Foggy" => 15,
    "Gogo" => 15,
    "Goolime" => 11,
    "Greeneye" => 15,
    "Hazy" => 18,
    "Hive" => 14,
    "Hop" => 15,
    "Imar" => 8,
    "Indie" => 16,
    "Jellime" => 9,
    "Jump" => 14,
    "Kinnowin" => 18,
    "Leap" => 14,
    "Lemonlime" => 12,
    "Lightning" => 10,
    "Limelime" => 12,
    "Mallard" => 17,
    "Mandarin" => 14,
    "Mary" => 12,
    "Meepo" => 5,
    "Mimo" => 15,
    "Mintydrizzel" => 6,
    "Mintyflav" => 15,
    "Mintyfresh" => 9,
    "Mintyswirl" => 12,
    "Misty" => 13,
    "Mo" => 10,
    "Mocha" => 15,
    "Momo" => 7,
    "Momomo" => 13,
    "Momomomo" => 16,
    "Montoya" => 12,
    "Ocean" => 14,
    "Orangin" => 15,
    "Pinkydink" => 10,
    "Pinkypanther" => 9,
    "Pinkyrosa" => 13,
    "Pinkytoe" => 10,
    "Pinkywinky" => 13,
    "Prim" => 14,
    "Pulsar" => 16,
    "Quacky" => 14,
    "Quasar" => 8,
    "Rapidly" => 18,
    "Razzy" => 20,
    "Redeye" => 17,
    "Rezzy" => 20,
    "Rima" => 10,
    "Rizzy" => 16,
    "Rojocuatro" => 7,
    "Rojodos" => 9,
    "Rojotres" => 6,
    "Rojouno" => 13,
    "Royal" => 7,
    "Rozzy" => 15,
    "Ruzzy" => 15,
    "Sea" => 14,
    "Shimmer" => 12,
    "Shiny" => 13,
    "Shock" => 13,
    "Shore" => 11,
    "Skip" => 8,
    "Slimelime" => 14,
    "Smoggy" => 17,
    "Snarl" => 12,
    "Snow" => 14,
    "Snowflake" => 16,
    "Snowstorm" => 12,
    "Snowy" => 16,
    "Sparkle" => 8,
    "Speedy" => 16,
    "Squirt" => 10,
    "Starry" => 19,
    "Sterling" => 12,
    "Stinger" => 15,
    "Sublime" => 14,
    "Sugar" => 9,
    "Sweet" => 6,
    "Swifty" => 14,
    "Taffy" => 12,
    "Tangerin" => 8,
    "Thunder" => 11,
    "Tidbit" => 10,
    "Tumult" => 15,
    "Velocity" => 9,
    "Vespa" => 15,
    "Wespy" => 12,
    "Whizzy" => 11,
    "Wispy" => 13,
    "Wospy" => 15,
    "Wuspy" => 11,
    "Yellah" => 15,
    "Yelley" => 9,
    "Yellow" => 16,
    "Yelloweye" => 12,
    "Yellup" => 12
}
@card_stats.default = 999

@rules = [
    "Each match is decided by a single duel, except for the semifinals and finals of both brackets, all of which are done as a best of three.",
    "Seeding is determined by the total stats of all of a participants entered marbles.",
    "A participant must enter between 2 to 4 marbles at time of registration that they will compete with.",
    "Once the tourney starts, players must keep all their current cards at their present level for the duration of the tournament. You can still upgrade cards so long as you do not enter the next tier (e.g. putting 27 extra p into a 32p card is ok, upgrading it to a 64p card is not)",
    "Registration is done on a first come, first serve basis. Registration will close once the number of participants has been reached deemed sufficient (minimum 16).",
    "The fee for entry is 4p. Once you are registered, Mesp will ping when he is able to take payments.",   
    "Once the tournament starts, matches can be done in any order except for the semifinals and up which will begin at a set time determined to maximize audience and convenience for participants.",  
    "They are just virtual marbles. Take it easy and roll with the flow. Don't get upset over upsets.",
    "For a match to be valid, two other tourney participants must spectate and verify the result of the match. Report a match using !report p1 p2 0-0",
    "A participant may not use the same marble for two matches in a row (individual matches in best-of-threes are considered distinct and swaps must occur between them)",
    "If a duel crashes, the duel is redone but the results of any stats already given are considered locked in. For example, if you win strength and then the duel crashes, you will automatically win strength in the rematch regardless of actual outcome.",
    "Rules are subject to change as clarification is needed in the future."
]
bot.join