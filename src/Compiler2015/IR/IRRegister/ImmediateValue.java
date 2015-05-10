package Compiler2015.IR.IRRegister;

public class ImmediateValue implements IRRegister {
	public int a;

	public ImmediateValue(int a) {
		this.a = a;
	}

	@Override
	public int getValue() {
		return -1;
	}

	@Override
	public String toString() {
		return Integer.toString(a);
	}
}
