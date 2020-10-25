# Uxie Marketplace functionality
# David "Mesp" Loewen

def get_marketplace_dir(id)
	return "/listingdb"
end

def get_listing_filename(id, offering)
	return "#{id}#{offering.downcase}.listing"
end

@bot.command(:add_listing) do |event, offering, *asking|
	id = event.message.author.id
	if File.exists?("#{get_marketplace_dir(id)}/#{get_listing_filename(id, offering)}")
        event.respond "#{event.message.author.name}, you already have a listing up for #{offering}!" 
    else
        File.open("#{get_marketplace_dir(id)}/#{get_listing_filename(id, offering)}", "w"){ |f| f.puts asking.join(" ") }
		event.respond "Listing created for #{offering}."
    end
end

@bot.command(:edit_listing) do |event, offering, *asking|

end

@bot.command(:delete_listing) do |event, offering|

end

@bot.command(:search) do |event, wanting|

end
