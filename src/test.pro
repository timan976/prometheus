Integer sum(Integer a, Integer b) {
	Integer result = a + b;
	print "sum(<a>, <b>) = <result>";
	return result;
}

sum(1, 2);
Integer count = 3; 
Integer foo = ++4;
Integer six = ++foo;
Integer six2 = foo--;
Bool bar = true == false;
bar = !(true || false && true);
bar = !!!!!!!!5--;
bar = true != false;
bar = !--1;
bar = !(foo >= 4);
count = (++foo + 100) % 3;
Integer a = 3.add(4);
Integer f = a.add(3).add(6).add(a);
String name = "Tim";
String fullname = name.append(" Philip ").append("Andersson");
Integer l = fullname.length();
Integer last = name.length() - 1;
String t = name.substr(0, 1);
Array names = ["Tim", "Johan"].append("Pelle");
String j = names.at(2);
Dict people = @["tim": @["age": 19, "surname": "Andersson"], "johan": @["age": 25, "surname": "Wanglov"]];
Dict tim = people.fetch("tim");
Integer age = tim.fetch("age");
String surname = tim.fetch("surname");
print "Hejsan Mr. <surname>!";
a = 8;
if(a < 8) {
	print "<a> < 8";
} else if(a == 8) { 
	Integer d = 4;
	if(bar == false)
		print "bar == false";
	print "<a> == 8";
} else {
	print "<a> > 8";
}
// The following line will result in an error since 
// the declaration of 'd' is in another scope.
//print d;

Integer c;
if(c = 3) 
	print "true";
else 
	print "false";

Integer i = 0;
while(i++ < 5)
	print "<i>";

print "============";

for(i = 0; i < 5; i++) {
	print "<i>";
}

print "============";

for(; i < 10; i++)
	print "<i>";

for(;i < 20;) 
	i++; 

print "============";

Integer m;
for(m = 3; m < 5; m++) {
	print "m: <m>";
}
