# Uxie Marketplace functionality
# David "Mesp" Loewen

def get_marketplace_dir(id)
	return "/listingdb"
end

def get_listing_filename(id, offering)
	return "#{id}#{offering.downcase}.listing"
end

@bot.command(:create_listing, usage: "!create_listing [offering] [asking]", min_args: 2, channels: ["test-channel", "marketplace-commands"]) do |event, offering, *asking|
	id = event.message.author.id
	if File.exists?("#{get_marketplace_dir(id)}/#{get_listing_filename(id, offering)}")
        event.respond "#{event.message.author.name}, you already have a listing up for #{offering}!" 
    else
        File.open("#{get_marketplace_dir(id)}/#{get_listing_filename(id, offering)}", "w"){ |f| f.puts asking.join(" ") }
		event.respond "Listing created for #{offering}."
    end
end

@bot.command(:update_listing, usage: "!update_listing [offering] [asking]", min_args: 2, channels: ["test-channel", "marketplace-commands"]) do |event, offering, *asking|
    id = event.message.author.id
    unless File.exists?("#{get_marketplace_dir(id)}/#{get_listing_filename(id, offering)}")
        event.respond "#{event.message.author.name}, you don't have a listing up for #{offering}!"
    else
        File.open("#{get_marketplace_dir(id)}/#{get_listing_filename(id, offering)}", "w"){ |f| f.puts asking.join(" ") }
        event.respond "Listing edited for #{offering}."
    end
end

@bot.command(:display_listing, usage: "!display_listing [offering]", min_args: 1, channels: ["test-channel", "marketplace-commands"]) do |event, offering|
    id = event.message.author.id
    unless File.exists?("#{get_marketplace_dir(id)}/#{get_listing_filename(id, offering)}")
		event.respond "#{event.message.author.name}, you don't have a listing up for #{offering}!"
	else
        File.open("#{get_marketplace_dir(id)}/#{get_listing_filename(id, offering)}", "r") do |f|
			event.respond "<@#{event.message.author.id}>'s listing:\n```\nOffering: #{offering}\nAsking for: #{f.read}\n```"
    	end
	end
end

@bot.command(:delete_listing, usage: "!delete_listing [offering]", min_args: 1, channels: ["test-channel", "marketplace-commands"]) do |event, offering|
    id = event.message.author.id
    unless File.exists?("#{get_marketplace_dir(id)}/#{get_listing_filename(id, offering)}")
        event.respond "#{event.message.author.name}, you don't have a listing up for #{offering}!"
    else
        File.delete("#{get_marketplace_dir(id)}/#{get_listing_filename(id, offering)}")
        event.respond "Listing deleted."
    end
end

@bot.command(:search, usage: "!search [wanting]", min_args: 1, channels: ["test-channel", "marketplace-commands"]) do |event, wanting|
	id = event.message.author.id
	matches = []
	Dir.glob("#{get_marketplace_dir(id)}/*#{wanting.downcase}*") do |filename|
		File.open("#{filename}", "r"){ |f| matches << "#{filename.split('/').pop.to_i}|||#{f.read}" }
	end
	if matches.empty?
		event.respond "No matches found for #{wanting}."
	else
		description = ""
		matches.each do |match|
			seller_id = match.split("|||")[0]
			seller_asking = match.split("|||")[1]
			description << "<@#{seller_id}>:\n**Wants:** #{seller_asking}\n"
		end
		event.send_embed do |embed|
			embed.title = "The following users are offering #{wanting}:"
			# embed.image = Discordrb::Webhooks::EmbedImage.new(url: 'https://upload.wikimedia.org/wikipedia/commons/5/55/Magnifying_glass_icon.svg')
			embed.description = description
		end
	end
end
