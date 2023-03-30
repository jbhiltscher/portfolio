#!/bin/bash
#set -x      #By the removing the comment on this line, your console will print out everything your code is doing. 


#------------------------------------------------------------------------
#STEP 1: REMOVE ALL INTERMEDIATE FILES

# You will not need to code this step until you create intermediate files,
# but the first thing your bash script should do is remove all of them. 
# Each time your script runs, you want new clean files to be created - 
# if we do not remove intermediate files, problems can be caused by
# old iterations of your script. To do this, consider looking up
# documentation on how to remove files only if they exist. 
#------------------------------------------------------------------------
final_file="Final_Output"
junk_folder="junk"
respace2_installed=0
dos2unix_installed=0


if [ -e "$junk_folder" ]; then
  rm -r "$junk_folder"
  echo " Deleted $junk_folder"
fi

[ -e "$final_file" ] && rm "$final_file"


#------------------------------------------------------------------------
#STEP 2: CREATE A FOR LOOP TO LOOP THROUGH FILES

# The second thing your script should do is create a for loop
# This for loop should loop through each Form*.csv file contained in the Data folder.
# Call your iterative variable 'file'. 90% of your code will be contained in this loop
# (Because we want to apply the same transformations to multiple files).
# Do not put "done" in this section, that will happen on Step 14.
#------------------------------------------------------------------------


# Your code here
INDIR=$1
PATTERN=$2

if [ ! -d "$INDIR" ]; then
  echo "No Input Directory"
  exit 1
fi

# Check if the PATTERN is provided
if [ -z "$PATTERN" ]; then
  echo "No Pattern Provided"
  exit 2
fi

echo " $INDIR/$PATTERN*"
for file in `ls $INDIR/$PATTERN*`

do
echo " $file"

./scripts/Check_config.sh $INDIR `echo "$file" | sed "s|$INDIR/||"`

if [ $? -eq 0 ]; then
    echo "Command found $INDIR and File for $file"
else
    echo "Command Failed for $file"
    if [ $? -eq 1 ]; then
        echo "No Input Directory"
        exit 1
    else
        echo "No Input File in Input Directory"
        exit 2
    fi
fi
echo " myfile $file"


#------------------------------------------------------------------------
#STEP 3: CREATE A LOCAL VARIABLE TO REPRESENT YOUR DOMAIN FILE PATH

# In your for loop, you should be looping over the Form*.csv files.
# However, you will need to reference the Domains_Form*.csv files as well.
# To do so, create a local variable that represents the Domains_Form*.csv file paths.
# You can do this by using a a combination of an echo and sed statement on your file variable. 
# Your file variable (that is being iterated in your for loop) will represent
# the Form*.csv file paths. You can create your new variable by modifying this. Name your new variable Domain.
# EX) use a sed statment to change 'Home/Downloads/FormA.csv' to 'Home/Downloads/Domains_FormA.csv'.
# HINT: Reference your file variable with $ - ($file will allow you to access your variable)
# HINT 2: Your code should start with 'Domain=echo $file | sed'
#------------------------------------------------------------------------

DOMAIN=`echo $file | sed "s/Form/Domains_Form/"`

if [ -z "$DOMAIN" ]; then
  echo "Error: sed command failed or did not produce a result."
  exit 1
fi
echo " $DOMAIN"



#------------------------------------------------------------------------
#STEP 4: SEPARATE THE ANSWER KEY AND STUDENT ANSWERS

# In this step, you will use grep statements on your file variable. 
# Save the answer key as AnswerKey, and student's answers as StudentAnswers.
# HINT: You can not assume that the answer key will always be the first line of the file.
#------------------------------------------------------------------------


grep "KEY" $file > AK
grep -v "KEY" $file > STU



#------------------------------------------------------------------------
#STEP 5: CREATE A TABLE OF 0's and 1's INDICATING IF STUDENTS GOT A QUESTION CORRECT

# We have written most of the code for this step for you. In the file structure
# you downloaded, you will see 3 R files: FirstConvert.R, SecondConvert.R and WidetoLong.R
# These files will perform this step for you (however, you need to read through these
# files and understand them. There will be a python code review where you recreate 
# these files.) Use the 'Rscript' function to call R files within the command line. 
# You will run the FirstConvert.R file, using your StudentAnswers as the first argument
# and your AnswerKey as the second argument. Save this output as FirstConvertOutput.
# HINT: These R scripts call packages that you may not have installed. 
# You will need to open R in the terminal, and use a install.packages() call to install these.
# HINT 2: This FirstConvertOutput is an example of an intermediary file that you need to remove.
#------------------------------------------------------------------------

if [ $reshape2_installed=0 ]; then
  if ! Rscript -e 'if (!require("reshape2")) { q(status=1) }' &> /dev/null; then
    echo "reshape2 package not found. Installing..."
    R -e 'install.packages("reshape2")'
    reshape2_installed=1
  else
    echo "reshape2 package already installed."
    reshape2_installed=1
  fi
fi

Rscript FirstConvert.R STU AK FCO

#------------------------------------------------------------------------
#STEP 6: CONVERT YOUR TABLE OF 0's and 1's FROM WIDE TO LONG FORM

# Similar to the Step above, we have already written an R script that does this for you.
# Call the WidetoLong.R file, using your FirstConvertOutput as the first argument,
# and WidetoLongOutput as your second argument (this will store your output).
# HINT: Again, this is another intermediary file that should be removed.
#------------------------------------------------------------------------


Rscript WidetoLong.R FCO WLO



#------------------------------------------------------------------------
#STEP 7: REMOVE QUOTES FROM WIDETOLONGOUTPUT

# If you take a look at the output from your call to WidetoLong.R, you will find quotes.
# These will interfere with later transformations. Write sed statement that 
# removes all quotes from your WidetoLongOutput file.
#------------------------------------------------------------------------



sed 's/"//g' WLO > NewWLO




#------------------------------------------------------------------------
#STEP 8: CALL NUMERIC.AWK TO FORMAT NUMBERS AS '001, 010, 100'

# We have provided you with a file called Numeric.awk. This file
# formats your WidetoLong output by adding leading zeros.
# this allows all the desired columns to have the same number of digits - 
# EX) 10 will be 010, 1 will be 001, and 100 will be 100.
# It will be your responsibility to read through this Numeric.awk file and 
# recreate it to be applied to your future DomainsReduced file in step 13. 
# Save your output as QuestionsSorted.
#------------------------------------------------------------------------



awk -f Numeric.awk NewWLO > QS




#------------------------------------------------------------------------
#STEP 9: REMOVE THE HEADER OF YOUR DOMAINS FILE

# Up until this point, we have only been working with the Form*.csv files. 
# We will now be working with the Domains_Form*.csv files. 
# The first step for working with these files is to remove the header, and save
# the resulting output as DomainsNoHeader (Take a look at your Domains_Form*.csv files
# and see why we want to remove the header). 
# In order to do this, you will need to use a sed statment on the domain
# variable you created in step 3. (Remember - to reference variables in Linux
# you need to use a $ - ($DomainsNoHeader) will let you reference your Domain variable. 
#------------------------------------------------------------------------

sed '1d' $DOMAIN > DNH

#------------------------------------------------------------------------
#STEP 10: SELECT AND SAVE ONLY THE 3RD AND 4TH COLUMNS OF YOUR NEWLY
#CREATED domain 

# We only want to select the 3rd and 4th columns of the DomainsNoHeader - 
# take a look at the Domains_Form*.csv files to see why this is the case.
# What information is being repeated? What information is included in the 
# Domains_Form*.csv files that is not included in the Form*.csv files?
# HINT - this is easily done using the cut command. Save your output as DomainsReduced.
#------------------------------------------------------------------------


cut -d $',' -f3,4 DNH > DR


#------------------------------------------------------------------------
#STEP 11: REPLACE THE COMMAS IN YOUR DOMAINSREDUCED FILE WITH SPACES

# Similar to how we removed the quotes in the WidetoLongOutput in step 7,
# use a sed statement to replace all commas in your DomainsReduced file with spaces.
# This allows us to format our numbers the same as we did to our WidetoLongOutput.
#------------------------------------------------------------------------




sed 's/,/ /g' DR > spaceDR




#------------------------------------------------------------------------
#STEP 12: CALL THE DOS2UNIX COMMAND ON THE DOMAINSREDUCEDFILE

# As we discussed in class, files sometimes come with invisible characters
# that will mess up the formatting of transformations.
# For example, new lines are denoted differently in different languages.
# To account for these differences, we run the dos2unix command.
# This formats the DomainsReduced file to remove these hidden characters.
#------------------------------------------------------------------------
if [ $dos2unix_installed=0 ]; then
  if which dos2unix >/dev/null; then
    dos2unix -o spaceDR
    dos2unix_installed=1
  else
    sed -i 's/^M//' spaceDR
    dos2unix_installed=1
  fi
fi

#------------------------------------------------------------------------
#STEP 13: CREATE AND CALL NUMERIC_DOMAIN.AWK TO FORMAT NUMBERS AS '001, 010, 100'

# In the same way we added leading 0's to the WidetoLongOutput in Step 8, 
# you will edit the Numeric_Domains.awk file to do the same process to your
# DomainsReduced file. 
# Make a copy of Numeric.awk called Numeric_Domain.awk.
# Edit the code to apply the transformations to the Domains_Form*.csv files. 
# Edit the corresponding column that we did in step 8.
# In doing so, we format our file to be joined with QuestionsSorted. 
# While the first Numeric.awk changed both the first and third columns, in
# this file you will only be changing the second column.
# Think to yourself - why is this the case?
# Save your output as DomainsSorted.
# HINT: You will need to print out both columns at the end of the awk file,
# but remember - your DomainsReduced file only has 2 columns.  
#------------------------------------------------------------------------



awk -f Numeric_Domain.awk spaceDR >DS


#------------------------------------------------------------------------
#STEP 14: JOIN THE QUESTIONSSORTED AND DOMAINSSORTED FILES

# This step is done for you. The below join statement will combine the two files you have
# created, and provide you with one comprehensive output. This final step will
# only work if you have done all the above steps correctly. 
# (and named your files what we have told you to name them). 
# Remember to go back and add conditional remove statments to remove
# all intermediary files you have created throughout the script.
#------------------------------------------------------------------------


# Joining sorted tables to create final output
join -1 3 -2 2 -o 1.1,1.2,1.3,2.1,1.4 QS DS >> Final_Output


#------------------------------------------------------------------------
# Remember to end your for loop with a 'done' statement.
#------------------------------------------------------------------------


# Your 'done' here
done


#------------------------------------------------------------------------
#STEP 15: TEST YOUR OUTPUT 

# To test if you have the correct output in your Final_Output file, run the wc command. 
# This command will return the number of words, lines and characters in your file. 
# HINT: The correct output for running your wc command is 3000   15000   42000
#------------------------------------------------------------------------

if [ ! -d "$junk_folder" ]; then
  mkdir "$junk_folder"
fi

for file in *; do
  if [ "$file" != "$final_file" ] && [ "$file" != "$1" ] && [ "$file" != "$0" ] && [[ ! "$file" =~ \. ]] && [ "$file" != "$junk_folder" ] && [ "$file" != "scripts" ]; then
    mv "$file" "$junk_folder"
  fi
done


wc Final_Output
# You can include your wc command here if you would like, or run it straight in the command line.




#------------------------------------------------------------------------
#STEP 16: RUN YOUR CODE ON STATRPS

# Up until this point we have been running and debugging code on your local machine. 
# You are now required to use the scp command to copy your Linux_Final folder to the statrps server
# As you may have noticed, we have only been looping over 2 files: FormA.csv and FormB.csv. On the 
# statrps server, we have designated a folder with 20+ forms, and require you to loop over those. 
# This prevents you from hard coding your answers, and requires you to write adaptable code. 
# If you have written your code correctly so far, this will be as easy as changing the file path in your
# for loop. 
# The files are stored in the following folder: /data/Stat125.
# The Form*.csv and Domains_Form*.csv files stored in this
# folder have the same names as those on your local machine
# so your code should not have to be edited much. 
#------------------------------------------------------------------------




# This step is not done inside of your Final.sh file.




#------------------------------------------------------------------------
#STEP 17: TEST YOUR OUTPUT

# Again on statrps, run the wc command to ensure your output is correct. 
# your output should be the following: 29850   149250   417900.
# MAKE SURE YOUR FINAL_OUTPUT FILE IS NAMED Final_Output AND IS STORED IN A FOLDER
# CALLED Linux_Final ON YOUR STATRPS USER. THE TA's WILL BE LOOKING FOR THIS
# TO GRADE YOUR FINAL. IF YOU DO NOT HAVE THIS ORGANIZED CORRECTLY, 
# WE WILL NOT BE ABLE TO GRADE YOUR FINAL. 
#------------------------------------------------------------------------





# This step may or may not be done in your Final.sh file, depending on how
# you chose to do step 15 - if you included your wc command in your Final.sh file,
# you only need to check the output after running your final on Statrps.






#------------------------------------------------------------------------
#STEP 18: (OPTIONAL)

# For extra credit, write a report that includes well documented code
# talking through the purpose of this assignment. Explain your code and your process.
# Additionally, answer the following questions:
# Why are we doing this? - What is the purpose in joining these two files?
# Explain the formatting process.
# What information is contained in the Form*.csv files?
# What information is contained in the Domains_Form*.csv files?
# The bulk of your code is formatting these files - does that surprise you?
# Do you see this as a common task that a data scientist might perform?

# When explaining your code, do so as if you were talking to someone
# who has never taken a linux course. To submit this report, email it 
# to the stat125@stat.byu.edu email.
#------------------------------------------------------------------------





# Submit a text or word document for step 18.






#------------------------------------------------------------------------
# __     __         _            ______ _       _     _              _   _ 
# \ \   / /        ( )          |  ____(_)     (_)   | |            | | | |
#  \ \_/ /__  _   _|/ _ __ ___  | |__   _ _ __  _ ___| |__   ___  __| | | |
#   \   / _ \| | | | | '__/ _ \ |  __| | | '_ \| / __| '_ \ / _ \/ _` | | |
#    | | (_) | |_| | | | |  __/ | |    | | | | | \__ \ | | |  __/ (_| | |_|
#    |_|\___/ \__,_| |_|  \___| |_|    |_|_| |_|_|___/_| |_|\___|\__,_| (_)
#                                                                          
#------------------------------------------------------------------------

