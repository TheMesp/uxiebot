require "sqlite3"

def opendb
	return SQLite3::Database.new "/root/discordbots/uxiebot/uxie.db"
end

# setup tables if they don't exist
def setup
	print "Creating tables..."
	db = opendb
	db.execute "PRAGMA foreign_keys = ON;"	

	db.execute <<-SQL
		CREATE TABLE IF NOT EXISTS listings(
			seller varchar(30),
			offering varchar(100),
			asking varchar(100),
			card_level int
		);
	SQL

	print "Tables created.\n"
end

def migrate_old_listings
	db = opendb
  Dir.glob("/listingdb/*") do |filename|
		File.open("#{filename}", "r") do |f|
			params = filename.match(/(\d+)(\w+)\+(\d{1,2})\.listing/).to_a + [f.read]
			params = params.drop(1)
			print("#{params}\n")
			db.execute("INSERT INTO listings (seller, offering, card_level, asking) VALUES (?, ?, ?, ?)", params)
		end
	end
end

# setup
# migrate_old_listings

	# db.execute("SELECT * FROM conferences") do |row|
	# 	print("#{row}\n")
	# end
	# db.execute("SELECT * FROM seasons") do |row|
	# 	print("#{row}\n")
	# end

	# db.execute("DELETE FROM seasons WHERE id=1")
	# print "\n"
	# db.execute("SELECT * FROM conferences") do |row|
	# 	print("#{row}\n")
	# end
	# db.execute("SELECT * FROM players") do |row|
	# 	print("#{row}\n")
	# end