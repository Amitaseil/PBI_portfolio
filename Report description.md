This report's main goal was to provide a reliable data and clear visualization on how well the dedicated retention team works with our clients. 
Unique clients that are active on our platform (activity is counted after person used our app/website features or after using any of our financial services) are counted and aggregated in different tables on daily/weekly/monthly basis.

Main challenges encountered while creating this report:
  1. Figuring out a way to aggregate clients for each period using BigQuery SQL not only based on their activity, but with two more layers - on which type of message they received during this period and have they opened/clicked on in or not.
     Example of the code that worked flawlessly can be found active_clients_weekly.SQL
  2. Creating PowerBI Cohort Analysis that will reflect retention of clients while also showing the impact of retention campaigns from different channels (transport types) and client reaction to such messages.
     On Retention Matrix v.2 page, you can find the main outcome of my work on this report. Columns here show activity period after registration (for example, if chosen period is "Week" - numbers represent each week after the registration).
     Rows have the following hierarchy: period -> project -> transport_type -> reaction_received.
     
     After combining a couple of field parameters with measures **active_clients_switch** and **cohort_%**, I was able to show cohort percentages differently on each level of hierarchy.
     
     As you can see on the screenshot, throughout _period_ and _project_ rows we calculate % of aclive clients compared to initial active clients number.
     But on _transport_type_ level (email, messenger, etc.), report is calculating % for each transport channel based on number of clients that received specific type of message during each specific period's column value and project.
     Futhermore, on the last hierarchy level _reaction_received_, % of clients that reacted in a specific way is calculated for each individual transport type.

     As a result, depending on chosen hierarchy level, this page's heatmap highlights main points of interest for client's retention.
     The team usually used it to find out what recent campaigns "reanimated" clients in the most effecient way and was able to compare them with one another in terms of effectiveness.

Other report examples can be found in a .zip file.
