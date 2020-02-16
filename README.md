# Uxiebot
A bot built to automate tournaments for trading cards in the Marblebase discord server.

## Usage Instructions
The process for beginning a tourney is to type in `!create_tourney [Name]` (the name can be multiple words and does not need to be enclosed in quotes.)

Once a tourney has been created, it is up to the tournament host to add participants using `!register [Name](only one word this time) [Marble1] [Marble2]`...etc. For example, `!register SomeDude Kinnowin++++ Meepo* Anarchy+`.

You can display these records by using `!display [name]` or `!display all` to view them all. This command can be used by anyone, but if you are not the tournament host you must add the tourney name after the command e.g. `!display Mesp The Cool Moody Championship` to display my record in The Cool Moody Championship tournament, assuming it exists.

If the tournament author needs to update a record, they can use `!update Mesp Anarchy+++`, which will add Anarchy+++ to my record if it was not already on there or replace a differently leveled anarchy if it already existed on my record.

Once all the registration is done, the formal bracket can be created by using `!start_tourney`. After this point, registration records are set in stone!

When a tourney is ongoing, match results can be reported in the following syntax: `!report Mesp Spex 3-2`. If you are not the tourney host, you again need to include the tourney name after the command.

The tourney will automatically be finalized and you will be open to start a new one after the bracket is filled out, but if you need to delete the tourney for whatever reason use `!delete_tourney`. This will also **permanently** delete the tourney bracket, so only do this if you really mean to!

Each person can host one tourney at a time (e.g. multiple tourneys can be going on simultaneously, all by different people).

Message me on discord if you have any further questions!