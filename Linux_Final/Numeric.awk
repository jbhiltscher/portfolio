
{
	if(length($1) < 2) first="00"$1       #if length of the first field is less than 2, add two zeros before the number. Ex:(001)
	
	else if(length($1) < 3)first="0"$1    #else if the length of the first field is less than 3, add 1 zero. Ex:(010)
	
	else first=$1                         #else leave the number alone. Ex:(100)
	
	if(length($3) < 2) third="00"$3       #Do the same thing for the third field.
	
	else if(length($3) < 3)third="0"$3
	
	else third=$3
	
	print first,$2,third,$4               #prints new columns in the correct order with columns 2 and 4.
}

