#This script reads in the file created in FirstConvert.R then converts it from
#wide to long format. This is necessary to calculate means and total scores 
#later on in your final report.

library(reshape2)
args <- commandArgs(TRUE)                             #passes external arguments into R for calculations
#read.table(args[1], stringsAsFactors = FALSE) -> mat #if you used write.table in FirstConvert.R then you would use this line. Otherwise you can use the line below.
load(args[1])                                      #loads the R file you created in FirstConvert.R
colnames(mat) <- c('id', 'form', 1:150)            #rename column names
newdata <- melt(mat, id=c("id", "form"))           #make it long format to perform calculatino. Duplicates ids 150 times
write.table(newdata, file = args[2], append = FALSE, sep = " ", row.names=FALSE, col.names = FALSE)   #save resulting table to a fie called you name externally.
q()    #quits R and returns to the bash script
