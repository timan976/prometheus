Integer foo(Integer b) {
	Integer i = 0;
	while(i < 5) {
		print i;
		i++;
	}
	return i;
}

String greeting(String name) {
	return "It's a pleasure to meet you, ".append(name).append("!");
}

Integer a = foo(3);
print a + 3;

print greeting("Tim");
