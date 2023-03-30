#This script compares the answers from key and result to indicate if the students
#got the question right or wrong. This is shown by 1's or 0's. The resulting dataframe
#has a column for student_id, form_letter, and then 0's and 1's indicating the answers.

library(reshape2)              #if this doesn't work, you may have to run install.packages in R within Ubuntu

read <- function(result,key){  #make function which will take the result and key file and compare answers to result in 1's and 0's.
DIM <- dim(result)             #gives us the dimensions of the result file
  
b <- matrix(rep(NA, DIM[1]*(DIM[2]-1)), nrow=DIM[1])     #pre-allocate the dimensions of the matrix b. We fill the matrix with NA's at the begnning.

  for (i in 1:nrow(result)){                             #loop through the files
    a <- key[1,2:ncol(key)] == result[i, 2:ncol(result)] #compare key answer to student's answers
    b[i, ] <- as.integer(a)                              #make a an integer
  }
  QS <- data.frame(id=result[,1],form=substr(key[1,1],1,1),b) #creates a dataframe with columns for student_id, form_letter, and then answers as 0's or 1's for each question
return(QS)  #returns the dataframe QS
}
