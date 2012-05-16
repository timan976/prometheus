Integer foo() {
	Integer i = 0;
	while(i < 5) {
		print i;
		i++;
	}
	return i;
}

Integer a = foo();
print a;
