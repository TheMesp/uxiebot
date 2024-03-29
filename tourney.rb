# get the data directory for a tourney id.

def get_tourney_dir(id)
	return "#{TOURNEY_DATA_DIR}/tourney#{id}"
end 

# creates the string to write to a user record file

def create_file_string(name, members)
    output = ""
    score = 0
    min_score = 999
    members.map!{|member| member.capitalize}
    entries = members.join(', ')
    members.each do |member|
        curr_score = 0
        # conv asterisk to 5 pluses
        member = member.gsub('*', '+++++')
        # set to 1.1 instead of 1.0 to prevent potential floating point errors
        increment = 1.1
        while member.end_with?('+') do
            curr_score += increment.to_i
            increment += 0.5
            member = member.chop
        end
        curr_score += @card_stats[member]
        min_score = curr_score if min_score > curr_score 
        score += curr_score
		output = member if @card_stats[member] < 0
    end
    score -= min_score if members.length == 4
	if output == ""
    	output << "Name: #{name.capitalize}\n"
    	output << "Entered cards: #{entries}\n"
    	output << "Stat total: #{score}"
	else
		output = "ERROR: Unknown card " + output
	end
    return output 
end

# returns a sorted array of players (strings) by seed.
# The format is [Mesp, Azelf, Uxie, ...]

def get_sorted_players(id)
    # first makes a hash map, sorts said hash map by seed, then prints in order of that hash.
    player_hash = Hash.new()
    Dir.glob("#{get_tourney_dir(id)}/*.record") do |filename|
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
    File.open("#{get_tourney_dir(id)}/playerindex", "r") do |f|
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
    File.open("#{get_tourney_dir(id)}/tourneyinfo", "r") do |f|
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
    name = name.gsub(/[^\w\d\s]/,"")
    Dir.glob("#{TOURNEY_DATA_DIR}/tourney**/tourneyinfo") do |filename|
        File.open("#{filename}", "r") do |f|
            tourney_name = f.read.split("\n")[0].split
            tourney_name.shift # remove the "Tourney Name: "
            tourney_name.shift
            tourney_name = tourney_name.join(" ")
            if(name.downcase.eql?(tourney_name.downcase))
				# get the id off of the file name: exploits the fact that the file path is only/letters/tourney1111111111/tourneyinfo to get the numbers
                # I can feel my programming practices prof crying as I type.
				fields = filename.split('/')
				id = fields[fields.length - 2].split('y').pop.to_i
				puts "id: #{id}"
				return id
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

# creates a block of text describing the tourney

def create_description_string(name, host, status, description, bracket)
    output = "```\n============\n#{name}\n============\n```\n"
    output << "Host: #{host}\n"
    output << "Status: #{status}\n"
	output << "Bracket: #{bracket}\n"
    output << "Link to Description: #{description}\n"
    return output
end

# returns a link to the message representing this tourney

def get_description_discord_message(event, id)
    if !File.exists?("#{get_tourney_dir(id)}/tourneyinfo")
        return nil
    else
        File.open("#{get_tourney_dir(id)}/tourneyinfo", "r") do |f|
            lines = f.read.split("\n")
            return nil if lines.length < 3
            msg_id = lines[3].split(":")[1].to_i
            list_channel = nil
            server_channels = event.channel.server.text_channels
            server_channels.each do |channel|
                list_channel = channel if channel.name.eql?("tourney-list")
            end
            return list_channel.load_message(msg_id)
        end 
    end
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

@bot.command(:ping) do |event|
    return "pong!"
end

# DA ROOLZ

@bot.command(:rule, aliases: [:rules]) do |event, num|
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

@bot.command(:predict) do |event, *fields|
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
    elsif fields.size == 1 || fields.uniq.size == 1 
        event.respond "I think that #{fields[0]} will choke horribly.\nTheir sense of humour is also profoundly lame."
    else
        event.respond "I think that #{fields.shuffle.pop} will win."
    end
end

# Perm check command.

@bot.command(:nuke, permission_level: 8) do |event, destination|
    return "`launching nukes`"
end

# register a player

@bot.command(:register) do |event, name, *members|
    id = event.message.author.id
    name = name.capitalize.gsub(/[^\w\d\s]/,"") 
    if File.exists?("#{get_tourney_dir(id)}/#{name.capitalize}.record")
        event.respond "#{name} has already been registered! Use `!display [name]` to see their record."
    elsif !File.exists?("#{get_tourney_dir(id)}/tourneyinfo")
        event.respond "You haven't made a tourney yet! Use `!create_tourney [name]` to make one."
    elsif !tourney_state(id).eql?("pending")
        event.respond "It's too late to register additional participants!"
    else
		file_string = create_file_string(name, members)
		if file_string.start_with?(@bad_cards)
			event.respond "#{file_string}\nNo changes made."
		else
			File.open("#{get_tourney_dir(id)}/#{name.capitalize}.record", "w") do |f|
			    f.puts(file_string)
			end
			# now get their position
			seed = get_sorted_players(id).find_index(name) + 1
			participant = JSON.parse(`curl -s --user #{CHALLONGE_USER}:#{CHALLONGE_TOKEN} -X POST -d "participant[name]=#{name}&participant[seed]=#{seed}" #{api_url(id)}/participants.json`)
			# add their ID to the index file for ease of access later
			pp participant
			File.open("#{get_tourney_dir(id)}/playerindex", "a") do |f|
				f.puts("#{name} #{participant['participant']['id'].to_i} ")
			end
			event.respond "#{name.capitalize} has been registered! Use `!display [name]` to see their record."
		end
	end
end

# display a record if it exists

@bot.command(:display) do |event, name, *tourneyname|
    id = event.message.author.id
    id = tourney_get_id(tourneyname.join(" ")) if tourneyname.size != 0
	puts "id: #{id}"
	if File.exists?("#{get_tourney_dir(id)}/tourneyinfo")
        name = "" if name == nil
        name = name.capitalize.gsub(/[^\w\d\s]/,"") 
        if name == "All" || name == "" || name == nil        
            # display all players
            if event.channel.name.eql?("registration-requests")
                event.respond("Please don't use !display all in registration requests!")
            else
                output = "Here's the registration record for everyone, sorted by seed:\n```"
                sorted_arr = get_sorted_players(id)
                sorted_arr.each_with_index do |player, index|
                    output << "##{sorted_arr.find_index(player)+1}:\n"
                    File.open("#{get_tourney_dir(id)}/#{player}.record", "r") do |f|
                        output << "#{f.read}"
                        output << "\n"
                        if index%10 == 9
                            event.respond("" + output + "\n```")
                            output = "```"
                        end
                    end
                end
                event.respond ("" + output + "\nTotal participants: #{sorted_arr.length}```")        
            end
        elsif File.exists?("#{get_tourney_dir(id)}/#{name}.record")
            # display given player
            File.open("#{get_tourney_dir(id)}/#{name}.record", "r") do |f|
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

@bot.command(:delete) do |event, name|
    id = event.message.author.id
    name = name.capitalize.gsub(/[^\w\d\s]/,"") 
    if File.exists?("#{get_tourney_dir(id)}/#{name}.record")
        File.delete("#{get_tourney_dir(id)}/#{name}.record")
        playerhash = get_player_hash(id)
        JSON.parse(`curl -s --user #{CHALLONGE_USER}:#{CHALLONGE_TOKEN} -X DELETE #{api_url(id)}/participants/#{playerhash[name]}.json`)
        
        participants = JSON.parse(`curl -s --user #{CHALLONGE_USER}:#{CHALLONGE_TOKEN} -X GET #{api_url(id)}/participants.json`)

        # recreate index file


        File.open("#{get_tourney_dir(id)}/playerindex", "w") do |f|
            output = ""
            participants.each do |participant|
                output << "#{participant['participant']['name']} #{participant['participant']['id'].to_i}\n"
            end
            f.puts(output)
        end
        event.respond "Deleted record for #{name}."
    else
        event.respond "#{name} has no record of entry to begin with."
    end
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

@bot.command(:opponent) do |event, name, *tourneyname|
    @bot.send_message(676655641816727560, "#{event.author.display_name} used !opponent #{name}")
	id = event.message.author.id
    id = tourney_get_id(tourneyname.join(" ")) if tourneyname.size != 0
    if !File.exists?("#{get_tourney_dir(id)}/tourneyinfo")
        event.respond "No ongoing tourney found. Remember, if you aren't hosting a tourney yourself you need to include the tourney name as a final parameter. E.g. `!opponent Mesp The Cool Moody Championship`."
    elsif File.exists?("#{get_tourney_dir(id)}/playerindex")
        name = name.capitalize
        if tourney_state(id).eql?("pending")
            event.respond("I don't know who your opponent is yet as the tourney is still in the signup phase, but here's the provisional bracket: https://challonge.com/uxie#{id}#{get_tourney_name(id)}")
        elsif File.exists?("#{get_tourney_dir(id)}/#{name}.record")
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

@bot.command(:update) do |event, name, *newmarbles|
    id = event.message.author.id
    name = name.capitalize.gsub(/[^\w\d\s]/,"") 
    # is the file real
    if File.exists?("#{get_tourney_dir(id)}/#{name}.record")
        # has the tourney already started
        if tourney_state(id).eql?("underway")
            event.respond "The tourney has already started, records can no longer be updated."
        elsif newmarbles.size == 0
            event.respond "You forgot to include the marbles to update, dumbo"
        elsif newmarbles.size == 1
            newmarble = newmarbles[0].capitalize.gsub(/[^\w\d\s\+\*]/,"")
            marbles = ""
            File.open("#{get_tourney_dir(id)}/#{name}.record", "r") do |f|
                marbles = f.read.split("\n")[1].gsub(/(Entered cards: )|,/,"")
            end
			# split string into array ["marble1", "marble2", ...]
			marbles = marbles.split
			# event.respond("#{newmarble}\n#{marbles}");
            # replace if marble exists, append otherwise
			marble_index = marbles.index{|marble| marble.sub(/[*+]+$/,"").eql?(newmarble.sub(/[*+]+$/,""))}
            if marble_index != nil
                marbles[marble_index] = newmarble;
            else
                marbles << newmarble
            end
            # recreate the registration file
			file_string = create_file_string(name, marbles)
			if file_string.start_with?(@bad_cards)
				event.respond "#{file_string}\nNo changes made."
			else
				File.open("#{get_tourney_dir(id)}/#{name}.record", "w") do |f|
					f.puts(file_string)
				end
				# now get their position
				seed = get_sorted_players(id).find_index(name) + 1
				playerhash = get_player_hash(id)
				response = `curl -s --user #{CHALLONGE_USER}:#{CHALLONGE_TOKEN} -X PUT -d "participant[seed]=#{seed}" #{api_url(id)}/participants/#{playerhash[name]}.json`
				event.respond "Updated record for #{name}."
        	end
		elsif newmarbles.size > 1
            # essentially reregister a player if multiple marbles given
			file_string = create_file_string(name, newmarbles)
			if file_string.start_with?(@bad_cards)
				event.respond "#{file_string}\nNo changes made."
			else
				File.open("#{get_tourney_dir(id)}/#{name}.record", "w") do |f|
					f.puts(file_string)
				end
				playerhash = get_player_hash(id)
				# now get their position
				seed = get_sorted_players(id).find_index(name) + 1
				response = `curl -s --user #{CHALLONGE_USER}:#{CHALLONGE_TOKEN} -X PUT -d "participant[seed]=#{seed}" #{api_url(id)}/participants/#{playerhash[name]}.json`
				event.respond "Re-registered #{name} with the given marbles, old team removed."
        	end
		end
    else
        event.respond "#{name}? Never heard of them. Maybe they should get registered."
    end
end

# update the record of a player to indicate last used marble

def update_last_used_marble(id, event, name, marble, bot)
    if(marble.eql?(""))
        event.respond "<@#{event.author.id}>, which marble did #{name} use?\nIf I don't confirm, try again."
        last_marble = ""
        cancel = false
        while(last_marble.eql? "")
            # wait a minute for a reply
            reaction_event = bot.add_await!(Discordrb::Events::MessageEvent, {timeout: 60})
            # check for timeout
            if reaction_event
                # make sure the message is by who we asked
                if reaction_event.author.id.eql?(event.author.id)
                    # remove all spaces and symbols, matching card_stats format
					# temp disable of this if: allows any field for last card used
                    if true || @card_stats[reaction_event.content.gsub(/[^\w\d]/, "").capitalize] > 0
                        # filter out newlines from the response
                        last_marble = reaction_event.content.gsub("\n", "") 
                    else
                        event.respond "No marble found matching #{reaction_event.content}. Please try again."
                    end
                end
            else
                event.respond "Timed out."
                last_marble = "unknown"
            end
        end
    else
        last_marble = marble
    end
    event.respond "Set last used marble for #{name } to #{last_marble}!"
    # need to get marbles to be able to recreate the file
    marbles = ""
    File.open("#{get_tourney_dir(id)}/#{name}.record", "r") do |f|
        marbles = f.read.split("\n")[1].gsub(/(Entered cards: )|,/,"")
    end
    # split string into array ["marble1", "marble2", ...]
    marbles = marbles.split
    # recreate the record file string, with a new line indicating last used marble
    new_file_string = create_file_string(name, marbles)
    new_file_string << "\nLast used marble: #{last_marble}"
    File.open("#{get_tourney_dir(id)}/#{name}.record", "w") do |f|
        f.puts(new_file_string)
    end
end

@bot.command(:set_last_card) do |event, name, marble, *tourneyname|
    id = event.message.author.id
    id = tourney_get_id(tourneyname.join(" ")) if tourneyname.size != 0
    if File.exists?("#{get_tourney_dir(id)}/tourneyinfo")
        if tourney_state(id).eql?("pending")
            event.respond "This tourney needs to start before you can set last used marbles!"
        elsif !File.exists?("#{get_tourney_dir(id)}/#{name}.record")
            event.respond "No record for #{name} found!"
        else
            update_last_used_marble(id,event,name,marble,@bot)
        end
    else
        event.respond "No tourney found. If you are not hosting one, include the tourney name at the end of the command, e.g. `!set_last_card Mesp Tumult++++++++++ Cool Moody Championship`."
    end
end
# bot match result reporting command

@bot.command(:report) do |event, p1, p2, score, *tourneyname|
    id = event.message.author.id
    id = tourney_get_id(tourneyname.join(" ")) if tourneyname.size != 0
    if p1 && p2 && score && File.exists?("#{get_tourney_dir(id)}/tourneyinfo")
        p1 = p1.capitalize.gsub(/[^\w\d\s]/,"") 
        p2 = p2.capitalize.gsub(/[^\w\d\s]/,"") 
        if tourney_state(id).eql?("pending")
            event.respond "You don't have a running tournament!"
        elsif !File.exists?("#{get_tourney_dir(id)}/#{p1}.record")
            event.respond "No record for #{p1} found!"
        elsif !File.exists?("#{get_tourney_dir(id)}/#{p2}.record")
            event.respond "No record for #{p2} found!"
        elsif !(score =~ /^\d+-\d+$/)
            event.respond "Score formatted incorrectly. Expected format: num-num (e.g. 3-2)"
        elsif @active_react
            event.respond "Only one report can run at a time!"
        else
            @active_react = true
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
                    reaction_event = @bot.add_await!(Discordrb::Events::ReactionAddEvent)
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
					@active_react = false
                    # can't use state here as complete requires finalize api call
                    if(tourney_done?(matches))
                        event.respond "And... That's the end of the tourney! Here's the final bracket: https://challonge.com/uxie#{id}#{get_tourney_name(id)}"
                        response = `curl -s --user #{CHALLONGE_USER}:#{CHALLONGE_TOKEN} -X POST #{api_url(id)}/finalize.json`
                        msg = get_description_discord_message(event, id)
                        if msg
                            msg.delete
                        end
                        FileUtils.rm_rf("#{get_tourney_dir(id)}")
                    else
                        event.respond "Scores reported! Take a look at the updated bracket here: https://challonge.com/uxie#{id}#{get_tourney_name(id)}"
                        update_last_used_marble(id,event,p1,"",@bot)
                        update_last_used_marble(id,event,p2,"",@bot)
                    end
                end
            end
            @active_react = false
        end
    else
        event.respond "Insufficent arguments. Expected format: `!report [player1] [player2] [num-num] [tourney name(not required if it is your own tourney)]`"
    end
    return nil
end

# print the bracket link

@bot.command(:bracket) do |event, *tourneyname|
    id = event.message.author.id
    id = tourney_get_id(tourneyname.join(" ")) if tourneyname.size != 0
    if File.exists?("#{get_tourney_dir(id)}/tourneyinfo")
        event.respond("https://challonge.com/uxie#{id}#{get_tourney_name(id)}")
    else
        event.respond("No tourney found. If you are not hosting one, include the tourney name at the end of the command, e.g. `!bracket Cool Moody Championship`.")
    end
end

# set description of a tourney

@bot.command(:set_description) do |event, description|
    id = event.message.author.id
    msg = get_description_discord_message(event,id)
    if msg
        new_content = msg.content.gsub(/(Link to Description:.*)/, "Link to Description: #{description}")
        msg.edit(new_content)
    else
        event.respond "Could not set description: you either do not have an active tourney, or your tourney was created before Uxie V3.0"
    end
end

# make the tournament with a given name

@bot.command(:create_tourney) do |event, *tname|
    if tname.size == 0
        event.respond("Name field cannot be blank! `!create_tourney [name]`")
    elsif !File.exists?("#{get_tourney_dir(event.author.id)}/tourneyinfo")        
        tname = tname.join(" ").gsub(/[^\w\d\s]/,"") #plz no naughty business
        tourney_type = verify_action(@bot, event, "What type of tourney would you like to host?\n:one:: Single Elimination\n:two:: Double Elimination\n:three:: Round Robin", ["\u0031\u20E3", "\u0032\u20E3", "\u0033\u20E3"])
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
            hold_third_place_match = tourney_type.eql?("single elimination") ? verify_action(@bot, event, "Would you like to hold a match for third place?", ["✅", "❌"]).eql?("✅").to_s : "false"
            result = `curl -s --user #{CHALLONGE_USER}:#{CHALLONGE_TOKEN} -X POST -d "tournament[name]=#{tname}&tournament[url]=uxie#{event.author.id()}#{tname.gsub(" ", "").downcase}&tournament[description]=#{event.author.username()}'s Tourney&tournament[tournament_type]=#{tourney_type}&tournament[hold_third_place_match]=#{hold_third_place_match}" https://api.challonge.com/v1/tournaments.json`
            Dir.mkdir(get_tourney_dir(event.author.id))
            # id of the message uxie sends to advert this tourney
            msg_id = nil
            server_channels = event.channel.server.text_channels
            server_channels.each do |channel|
                msg_id = channel if channel.name.eql?("tourney-list")
            end
            msg_id = msg_id.send(create_description_string(tname, event.author.username, "OPEN FOR REGISTRATION", "#{event.author.username}'s Tourney", "https://challonge.com/uxie#{event.author.id}#{tname.gsub(" ", "").downcase}")).id
            File.open("#{get_tourney_dir(event.author.id)}/tourneyinfo", "w") do |f|
                f.puts("Tourney Name: #{tname}\nOrganizer: #{event.author.username}\nBracket Link: https://challonge.com/uxie#{event.author.id()}#{tname.gsub(" ", "").downcase}\nMessage ID (internal):#{msg_id}")
            end
            event.respond("Your tournament has been created, #{event.author.username}!
            \nUse `!set_description (message link here)` if you want to link a post detailing rules and prizes to the #tourney-list post. 
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

@bot.command(:start_tourney) do |event|
    id = event.author.id
    if !File.exists?("#{get_tourney_dir(id)}/tourneyinfo")
        event.respond "You haven't made a tourney yet, #{event.author.username}! Use `!create_tourney (Tourney name)` to get started."
    elsif tourney_state(id).eql?("underway")
        event.respond "You have already started your tourney, #{event.author.username}!"
    else
        players = get_sorted_players(id)
        if players.size < 4
            event.respond "You don't have enough players registered to start this tourney! You need at least 4."
        elsif verify_action(@bot, event, "Are you sure you want to start your tourney? After you start, participants are set!", ["✅", "❌"]).eql?("✅")
            # start the tourney!
            response = `curl -s --user #{CHALLONGE_USER}:#{CHALLONGE_TOKEN} -X POST -d "include_participants=1" #{api_url(id)}/start.json`
            msg = get_description_discord_message(event,id)
            if msg
                new_content = msg.content.gsub("OPEN FOR REGISTRATION", "ONGOING")
                msg.edit(new_content)
            end
            event.respond "Your tourney is now 🎉 UNDERWAY! 🎉\nHere's the bracket: https://challonge.com/uxie#{id}#{get_tourney_name(id)}"
        end
    end
    return nil
end

# delete the tourney
@bot.command(:delete_tourney) do |event|
    id = event.author.id
    if(File.exists?("#{get_tourney_dir(id)}/tourneyinfo") && verify_action(@bot,event,"Are you sure you want to delete your tourney? This will delete every last trace of it, including your bracket!", ["✅", "❌"]).eql?("✅"))    
        response = `curl -s --user #{CHALLONGE_USER}:#{CHALLONGE_TOKEN} -X DELETE #{api_url(id)}.json`
        msg = get_description_discord_message(event, id)
        if msg
            msg.delete
        end
        FileUtils.rm_rf("#{get_tourney_dir(id)}")
        event.respond "Your tourney has been deleted. Way to ragequit, huh?"     
    end
    return nil
end

# display tourney info

@bot.command(:display_tourney) do |event, *tourneyname|
    id = event.message.author.id
    id = tourney_get_id(tourneyname.join(" ").gsub(/[^\w\d\s]/,"")) if tourneyname.size != 0
    puts id
    if File.exists?("#{get_tourney_dir(id)}/tourneyinfo")
        File.open("#{get_tourney_dir(id)}/tourneyinfo", "r") do |f|
            event.respond("Here's the tourney details:\n```\n#{f.read}\n```")
        end
    else
        event.respond("You don't have an active tourney! Use `!display_tourney [tourney name]` to view someone elses.")
    end
end
