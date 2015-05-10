package Compiler2015.IR.Instruction;

import Compiler2015.IR.IRRegister.IRRegister;
import Compiler2015.IR.IRRegister.VirtualRegister;

/**
 * rd = func()
 * If return type of func is void, rd is useless.
 */
public class Call extends IRInstruction implements SingleSource {
	public IRRegister func;

	public Call(VirtualRegister rd, IRRegister func) {
		this.rd = rd.clone();
		this.func = func.clone();
	}

	@Override
	public String toString() {
		return "Call " + rd +  " = " + func;
	}

	@Override
	public int getRs() {
		return func.getValue();
	}

	@Override
	public void setRsVersion(int x) {
		if (func instanceof VirtualRegister)
			((VirtualRegister) func).setVersion(x);
	}
}
