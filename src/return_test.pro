Integer foo(Integer b) {
	Integer i = 0;
	for(i = 0; i < 5; i++) {
		print i;
	}
	return i;
}

String greeting(String name) {
	return "It's a pleasure to meet you, ".append(name).append("!");
}

Integer a = foo(3);
print a + 3;

print greeting("Tim");
