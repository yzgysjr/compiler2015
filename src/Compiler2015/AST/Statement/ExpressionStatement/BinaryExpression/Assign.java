package Compiler2015.AST.Statement.ExpressionStatement.BinaryExpression;

import Compiler2015.AST.Statement.ExpressionStatement.CastExpression;
import Compiler2015.AST.Statement.ExpressionStatement.Expression;
import Compiler2015.Environment.Environment;
import Compiler2015.Exception.CompilationError;
import Compiler2015.IR.CFG.ExpressionCFGBuilder;
import Compiler2015.IR.IRRegister.ArrayRegister;
import Compiler2015.IR.IRRegister.ImmediateValue;
import Compiler2015.IR.IRRegister.VirtualRegister;
import Compiler2015.IR.Instruction.Move;
import Compiler2015.IR.Instruction.ReadArray;
import Compiler2015.IR.Instruction.WriteArray;
import Compiler2015.Type.*;
import Compiler2015.Utility.Panel;

/**
 * a = b
 */
public class Assign extends BinaryExpression {
	public Assign(Expression left, Expression right) {
		super(left, right);
	}

	public static Expression getExpression(Expression a1, Expression a2, String operator) {
		if (!a1.isLValue)
			throw new CompilationError("Expression to the left of = is not left-value.");

		if (a1.type instanceof VoidType || a2.type instanceof VoidType)
			throw new CompilationError("Cannot operate on void.");

		if (a1.type instanceof IntType) {
			if (a2.type instanceof StructOrUnionType)
				throw new CompilationError("Type Error");
		}
		if (a1.type instanceof CharType) {
			if (a2.type instanceof StructOrUnionType)
				throw new CompilationError("Type Error");
		}
		if (a1.type instanceof StructOrUnionType) {
			if (a2.type instanceof IntType)
				throw new CompilationError("Type Error");
			if (a2.type instanceof CharType)
				throw new CompilationError("Type Error");
			if (a2.type instanceof FunctionType)
				throw new CompilationError("Type Error");
			if (a2.type instanceof FunctionPointerType)
				throw new CompilationError("Type Error");
			if (a2.type instanceof ArrayPointerType)
				throw new CompilationError("Type Error");
			if (a2.type instanceof VariablePointerType)
				throw new CompilationError("Type Error");
		}
		if (a1.type instanceof FunctionType) {
			if (a2.type instanceof IntType)
				throw new CompilationError("Type Error");
			if (a2.type instanceof CharType)
				throw new CompilationError("Type Error");
			if (a2.type instanceof StructOrUnionType)
				throw new CompilationError("Type Error");
			if (a2.type instanceof FunctionType)
				throw new CompilationError("Type Error");
			if (a2.type instanceof FunctionPointerType)
				throw new CompilationError("Type Error");
			if (a2.type instanceof ArrayPointerType)
				throw new CompilationError("Type Error");
			if (a2.type instanceof VariablePointerType)
				throw new CompilationError("Type Error");
		}
		if (a1.type instanceof FunctionPointerType) {
			if (a2.type instanceof StructOrUnionType)
				throw new CompilationError("Type Error");
		}
		if (a1.type instanceof ArrayPointerType) {
			if (a2.type instanceof IntType)
				throw new CompilationError("Type Error");
			if (a2.type instanceof CharType)
				throw new CompilationError("Type Error");
			if (a2.type instanceof StructOrUnionType)
				throw new CompilationError("Type Error");
			if (a2.type instanceof FunctionType)
				throw new CompilationError("Type Error");
			if (a2.type instanceof FunctionPointerType)
				throw new CompilationError("Type Error");
			if (a2.type instanceof ArrayPointerType)
				throw new CompilationError("Type Error");
			if (a2.type instanceof VariablePointerType)
				throw new CompilationError("Type Error");
		}
		if (a1.type instanceof VariablePointerType) {
			if (a2.type instanceof StructOrUnionType)
				throw new CompilationError("Type Error");
		}

		if ((a1.type instanceof StructOrUnionType) != (a2.type instanceof StructOrUnionType))
			throw new CompilationError("Incompatible type.");
		if (a1.type instanceof StructOrUnionType && (!operator.equals("=") || !a1.type.equals(a2.type)))
			throw new CompilationError("Incompatible type.");

		if (!(a1.type instanceof StructOrUnionType || a2.type instanceof StructOrUnionType)
				&& (!CastExpression.castable(a1.type, IntType.instance) || !CastExpression.castable(a2.type, IntType.instance)))
			throw new CompilationError("Incompatible type.");

		if (operator.equals("="))
			return new Assign(a1, a2);
		if (operator.equals("*="))
			return new Assign(a1.clone(), new Multiply(a1, a2));
		if (operator.equals("/="))
			return new Assign(a1.clone(), new Divide(a1, a2));
		if (operator.equals("%="))
			return new Assign(a1.clone(), new Modulo(a1, a2));
		if (operator.equals("+="))
			return new Assign(a1.clone(), Add.getExpression(a1, a2));
		if (operator.equals("-="))
			return new Assign(a1.clone(), Subtract.getExpression(a1, a2));
		if (operator.equals("<<="))
			return new Assign(a1.clone(), new ShiftLeft(a1, a2));
		if (operator.equals(">>="))
			return new Assign(a1.clone(), new ShiftRight(a1, a2));
		if (operator.equals("&="))
			return new Assign(a1.clone(), new BitwiseAnd(a1, a2));
		if (operator.equals("^="))
			return new Assign(a1.clone(), new BitwiseXOR(a1, a2));
		if (operator.equals("|="))
			return new Assign(a1.clone(), new BitwiseOr(a1, a2));
		throw new CompilationError("Internal Error");
	}

	@Override
	public String getOperator() {
		return "=";
	}

	@Override
	public void emitCFG(ExpressionCFGBuilder builder) {
		left.emitCFG(builder);
		right.emitCFG(builder);
		if (left.type instanceof StructOrUnionType) {
			left.convertArrayRegisterToPointer(builder);
			right.convertArrayRegisterToPointer(builder);

			StructOrUnionType type = (StructOrUnionType) left.type;
			int size = type.sizeof(), registerSize = Panel.getRegisterSize();
			for (int i = 0; i < size; i += registerSize) {
				VirtualRegister t = Environment.getVirtualRegister();
				builder.addInstruction(new ReadArray(t, new ArrayRegister((VirtualRegister) right.tempRegister, new ImmediateValue(i), registerSize)));
				builder.addInstruction(new WriteArray(new ArrayRegister((VirtualRegister) left.tempRegister, new ImmediateValue(i), registerSize), t));
			}
			tempRegister = right.tempRegister.clone();
		} else if (left.tempRegister instanceof ArrayRegister) {
			right.readInArrayRegister(builder);
			builder.addInstruction(new WriteArray((ArrayRegister) left.tempRegister, right.tempRegister));
			tempRegister = right.tempRegister.clone();
		} else if (left.tempRegister instanceof VirtualRegister) {
			right.readInArrayRegister(builder);
			builder.addInstruction(new Move((VirtualRegister) left.tempRegister, right.tempRegister));
			tempRegister = right.tempRegister.clone();
		} else
			throw new CompilationError("Internal Error.");
	}

	@Override
	public void readInArrayRegister(ExpressionCFGBuilder builder) {
		if (tempRegister instanceof ArrayRegister) {
			VirtualRegister newReg = Environment.getVirtualRegister();
			builder.addInstruction(new ReadArray(newReg, (ArrayRegister) tempRegister));
			tempRegister = newReg.clone();
		}
	}

	@Override
	public Expression rebuild() {
		return new Assign(left.rebuild(), right.rebuild());
	}

}
