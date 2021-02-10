# Uxie Marketplace functionality
# David "Mesp" Loewen

def get_marketplace_dir(id)
	return "/listingdb"
end

def get_listing_filename(id, offering, lvl)
	return "#{id}#{offering.downcase}+#{lvl}.listing"
end

def card_valid?(card)
	return @card_stats["#{card.capitalize}"] > 0
end
@bot.command(:create_listing, description: "Create a listing for a marble. Level will be 0 if no level number provided.", usage: "!create_listing [offering] [level(0-10)] [asking]", min_args: 3, channels: ["test-channel", "marketplace-commands"]) do |event, offering, level, *asking|
	id = event.message.author.id
	return "Don't use + or * symbols to set level. Instead, use the level parameter. E.g. `!create_listing Tumult 5 A Nice Cup of Hot Chocolate` to list a Tumult*." if (offering.include?('*') || offering.include?('+'))
	return "Unknown card #{offering}." unless card_valid?(offering)
	# special case if lvl not included
	unless (level =~ /\d/) == 0
		asking.unshift(level)
		level = "0"
	end
	
	if File.exists?("#{get_marketplace_dir(id)}/#{get_listing_filename(id, offering, level)}")
        event.respond "#{event.message.author.name}, you already have a listing up for #{offering} lvl #{level}!" 
    else
        File.open("#{get_marketplace_dir(id)}/#{get_listing_filename(id, offering, level)}", "w"){ |f| f.puts asking.join(" ") }
		event.respond "Listing created for #{offering}."
    end
end

@bot.command(:update_listing, description: "Update your listing for a marble, changing what you want for it.", usage: "!update_listing [offering] [level(0-10)] [asking]", min_args: 3, channels: ["test-channel", "marketplace-commands"], aliases: [:edit_listing]) do |event, offering, level, *asking|
    id = event.message.author.id
	return "Unknown card #{offering}." unless card_valid?(offering)
	# special case if lvl not included
	unless (level =~ /\d/) == 0
		asking.unshift(level)
		level = "0"
	end
    unless File.exists?("#{get_marketplace_dir(id)}/#{get_listing_filename(id, offering, level)}")
        event.respond "#{event.message.author.name}, you don't have a listing up for #{offering} lvl #{level}!"
    else
        File.open("#{get_marketplace_dir(id)}/#{get_listing_filename(id, offering, level)}", "w"){ |f| f.puts asking.join(" ") }
        event.respond "Listing edited for #{offering}."
    end
end

@bot.command(:display_listing, description: "display your own listing for a marble", usage: "!display_listing [offering] [level(0-10)]", min_args: 2, channels: ["test-channel", "marketplace-commands"]) do |event, offering, level|
    id = event.message.author.id
	return "Unknown card #{offering}." unless card_valid?(offering)
    unless File.exists?("#{get_marketplace_dir(id)}/#{get_listing_filename(id, offering, level)}")
		event.respond "#{event.message.author.name}, you don't have a listing up for #{offering} at level #{level}!"
	else
        File.open("#{get_marketplace_dir(id)}/#{get_listing_filename(id, offering, level)}", "r") do |f|
			event.respond "<@#{event.message.author.id}>'s listing:\n```\nOffering: #{offering}\nAsking for: #{f.read}\n```"
    	end
	end
end

@bot.command(:delete_listing, description: "remove your own listing from the listing database", usage: "!delete_listing [offering] [level(0-10)]", min_args: 2, channels: ["test-channel", "marketplace-commands"], aliases: [:remove_listing, :destroy_listing]) do |event, offering, level|
    id = event.message.author.id
	return "Unknown card #{offering}." unless card_valid?(offering)
    unless File.exists?("#{get_marketplace_dir(id)}/#{get_listing_filename(id, offering, level)}")
        event.respond "#{event.message.author.name}, you don't have a listing up for #{offering} at level #{level}!"
    else
        File.delete("#{get_marketplace_dir(id)}/#{get_listing_filename(id, offering, level)}")
        event.respond "Listing deleted."
    end
end

@bot.command(:search, description: "Search for a specific marble in the listing database", usage: "!search [wanting]", min_args: 1, channels: ["test-channel", "marketplace-commands"], aliases: [:search_listing, :search_listings]) do |event, wanting|
	id = event.message.author.id
	return "Unknown card #{wanting}." unless card_valid?(wanting)
	matches = []
	Dir.glob("#{get_marketplace_dir(id)}/*#{wanting.downcase}+*") do |filename|
		File.open("#{filename}", "r"){ |f| matches << "#{filename.split('/').pop.to_i}|||#{filename.split('+').pop.to_i}|||#{f.read}" }
	end
	if matches.empty?
		event.respond "No matches found for #{wanting}."
	else
		description = ""
		matches.each do |match|
			seller_id = match.split("|||")[0]
			seller_level = match.split("|||")[1]
			seller_asking = match.split("|||")[2]
			description << "<@#{seller_id}>: **(LEVEL #{seller_level})**\n**Wants:** #{seller_asking}\n"
		end
		event.send_embed do |embed|
			embed.title = "The following users are offering #{wanting}:"
			embed.colour = 15183055 # Pink Pearl
			embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: 'https://www.pinclipart.com/picdir/big/523-5232872_magnifying-glass-clipart.png')
			embed.description = description
		end
	end
end
