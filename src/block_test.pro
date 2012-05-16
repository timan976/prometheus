Block double = ^(Integer a) { 
	return a*2;
}

Array nums = [1, 2, 3];
print double(nums[2]);
print nums.map(^(Integer a) {
	return a^2;
});
print nums.map(double);

Void foo() {
	Integer c = 3;
	Block b = ^() {
		print c;
		print nums;
	}
	b();
}
foo();
