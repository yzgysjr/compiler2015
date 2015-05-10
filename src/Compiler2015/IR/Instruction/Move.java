package Compiler2015.IR.Instruction;

import Compiler2015.IR.IRRegister.IRRegister;
import Compiler2015.IR.IRRegister.VirtualRegister;

/**
 * rd = rs
 */
public class Move extends IRInstruction implements SingleSource {
	public IRRegister rs;

	public Move(VirtualRegister rd, IRRegister rs) {
		this.rd = rd;
		this.rs = rs;
	}

	@Override
	public String toString() {
		return "Move " + rd + " = " + rs;
	}

	@Override
	public int getRs() {
		return rs.getValue();
	}

	@Override
	public void setRsVersion(int x) {
		if (rs instanceof VirtualRegister)
			((VirtualRegister) rs).setVersion(x);
	}
}
