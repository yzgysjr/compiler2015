grammar Compiler2015;

@parser::header {
import Compiler2015.AST.*;
import Compiler2015.AST.Statement.*;
import Compiler2015.AST.Statement.ExpressionStatement.BinaryExpression.*;
import Compiler2015.AST.Statement.ExpressionStatement.*;
import Compiler2015.AST.Statement.ExpressionStatement.UnaryExpression.*;
import Compiler2015.Type.*;
import Compiler2015.Environment.*;
import Compiler2015.Exception.*;
import Compiler2015.Utility.*;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.Stack;
}

/* Top level */

compilationUnit
	: (functionDefinition | declaration | Semi)* EOF
	;

declaration
@after {
	TypeAnalyser.exit();
}
	:	Typedef
		typeSpecifier
			{
				TypeAnalyser.enter($typeSpecifier.ret);
			}
		(declaratorList)?
		Semi #declaration1
	|	typeSpecifier
			{
				TypeAnalyser.enter($typeSpecifier.ret);
			}
		(initDeclaratorList)? Semi #declaration2
	;

functionDefinition
locals [ FunctionType type, String name, CompoundStatement s = null,
			ArrayList<Type> parameterTypes, ArrayList<String> parameterNames,
			boolean hasVaList = false, int uId = -1,
			Stack<Loop> loopStack = null, Type returnType = null,
			ArrayList<Type> typePassDown, ArrayList<String> namePassDown]
@init {
	$parameterTypes = new ArrayList<Type>();
	$parameterNames = new ArrayList<String>();
	$loopStack = Environment.loopStack;
	Environment.loopStack = new Stack<>();
}
@after {
	TypeAnalyser.exit();
	Environment.loopStack = $loopStack;
}
	:	typeSpecifier { $returnType = $typeSpecifier.ret; }
		(STAR { $returnType = new VariablePointerType($returnType); } )*
		{ TypeAnalyser.enter($returnType); }
		directDeclarator
		L1 (parameterTypeList
			{
				$parameterTypes = $parameterTypeList.types;
				$parameterNames = $parameterTypeList.names;
				$hasVaList = $parameterTypeList.hasVaList;
				if ($parameterNames.size() != 0 && (new HashSet<>($parameterNames).size()) != $parameterNames.size())
					throw new CompilationError("parameter should have different names.");
				for (String name : $parameterNames)
					if (name == null || name.equals(""))
						throw new CompilationError("No parameter name.");
			}
		)? R1
		{
			TypeAnalyser.addParameter($parameterTypes, $parameterNames, $hasVaList);
			$type = (FunctionType) TypeAnalyser.analyse(true);
			$name = $directDeclarator.name;

			if (!Environment.isCompleteType($type))
				throw new CompilationError("Incomplete type.");

			Environment.functionReturnStack.push($type.returnType);
			if (Environment.symbolNames.currentScope == 1)
				$uId = Environment.symbolNames.defineVariable($name, $type);
			else
				$uId = Environment.symbolNames.defineLocalFunction($name, $type);

			$parameterTypes = $type.parameterTypes;
			$parameterNames = $type.parameterNames;

			$typePassDown = new ArrayList<>($parameterTypes);
			$namePassDown = new ArrayList<>($parameterNames);
//			if (!($returnType instanceof VoidType)) {
//				$typePassDown.add($returnType);
//				$namePassDown.add(".return");
//			}
		}
		compoundStatement[$typePassDown, $namePassDown]
		{
			$s = $compoundStatement.ret;
			$s.youAreAFrame(Environment.symbolNames.currentScope + 1);
			Environment.symbolNames.defineVariable($uId, $type, $s);
			Environment.functionReturnStack.pop();
		}
	;

initDeclaratorList
	: initDeclarator (Comma initDeclarator )*
	;

initDeclarator
locals [Type type, String name, SimpleInitializerList init = null, int uId]
	: declarator
		{
			$type = TypeAnalyser.analyse();
			$name = $declarator.name;
			$uId = Environment.symbolNames.defineVariable($name, $type);
		}
		(EQ initializer
			{
				$init = $initializer.ret;
				Environment.symbolNames.defineVariable($uId, $type, $init);
			}
		)?
	;

typeSpecifier returns [Type ret]
	:	'void' { $ret = VoidType.instance; }
	|	'char' { $ret = CharType.instance; }
	|	'int' { $ret = IntType.instance;  }
	|	'va_list' { $ret = new VariablePointerType(CharType.instance); }
	|	typedefName { $ret = $typedefName.ret; }
	|	structOrUnionSpecifier { $ret = $structOrUnionSpecifier.ret; }
	;

structOrUnionSpecifier returns [Type ret]
locals [boolean isUnion, String name]
@init {
	$name = "";
}
	:	structOrUnion
		{
			$isUnion = $structOrUnion.isUnion;
		}
		(Identifier { $name = $Identifier.text; } )?
		L3 { StructBuilder.enter($name, $isUnion); }
			(structDeclaration
				{
					StructBuilder.addAttributes($structDeclaration.types, $structDeclaration.names);
				}
			)*
		R3 { $ret = StructBuilder.exit(); } #structOrUnionSpecifier1
	|	structOrUnion { $isUnion = $structOrUnion.isUnion; }
		Identifier
		{
			$name = $Identifier.text;
			$ret = StructBuilder.declareDirectly($name, $isUnion);
		} #structOrUnionSpecifier2
	;

structOrUnion returns [boolean isUnion]
	:	'struct' { $isUnion = false; }
	|	'union'  { $isUnion = true; }
	;

/**
 * declaration inside struct / union
 */
structDeclaration returns [ArrayList<Type> types, ArrayList<String> names]
@init {
	$types = new ArrayList<Type>();
	$names = new ArrayList<String>();
}
@after {
	for (Type t : $types)
		if (t instanceof FunctionType)
			throw new CompilationError("Could not declare / define functions inside struct / union.");
	TypeAnalyser.exit();
}
	:	typeSpecifier { TypeAnalyser.enter($typeSpecifier.ret); }
		(
			d1 = declarator
			{
				$types.add(TypeAnalyser.analyse());
				$names.add($d1.name);
			}
			(
				Comma d2 = declarator
				{
					$types.add(TypeAnalyser.analyse());
					$names.add($d2.name);
				}
			)*
		)? Semi
	;

declarator returns [String name]
locals [int n = 0]
@after {
	for (int i = 0; i < $n; ++i)
		TypeAnalyser.addStar();
}
	:	(STAR { ++$n; } )*
		directDeclarator { $name = $directDeclarator.name; }
	;

plainDeclarator returns [Type type, String name]
	: declarator
		{
			$type = TypeAnalyser.analyse();
			$name = $declarator.name;
			Environment.symbolNames.defineTypedefName($name, $type);
		}
	;

declaratorList
	: plainDeclarator (Comma plainDeclarator)*
	;

directDeclarator returns [String name]
	:	Identifier { $name = $Identifier.text; }
	|	'(' declarator ')' { $name = $declarator.name; }
	|	d1 = directDeclarator { $name = $d1.name; }
		'[' constantExpression ']' { TypeAnalyser.addArray($constantExpression.ret); }
	|	d2 = directDeclarator { $name = $d2.name;  }
		'[' ']' { TypeAnalyser.addArray(null); }
	|	d3 = directDeclarator { $name = $d3.name; }
		'(' ')' { TypeAnalyser.addParameter(); }
	|	d4 = directDeclarator { $name = $d4.name; }
		'(' parameterTypeList ')' { TypeAnalyser.addParameter($parameterTypeList.types, $parameterTypeList.names, $parameterTypeList.hasVaList); }
	;

parameterTypeList returns [ArrayList<Type> types, ArrayList<String> names, boolean hasVaList = false]
	:	parameterList
		{
			$types = $parameterList.types;
			$names = $parameterList.names;
		}
		(Comma '...' { $hasVaList = true; } )?
	;

parameterList returns [ArrayList<Type> types, ArrayList<String> names]
@init {
	$types = new ArrayList<Type>();
	$names = new ArrayList<String>();
}
	:	p1 = parameterDeclaration
		{
			$types.add($p1.type);
			$names.add($p1.name);
		}
		(Comma p2 = parameterDeclaration
			{
				$types.add($p2.type);
				$names.add($p2.name);
			}
		)*
	;

parameterDeclaration returns [Type type, String name]
@after {
	TypeAnalyser.exit();
}
	:	t1 = typeSpecifier
		{
			TypeAnalyser.enter($typeSpecifier.ret);
			$type = $typeSpecifier.ret;
			$name = "";
		} #parameterDeclaration1
	|	t2 = typeSpecifier { TypeAnalyser.enter($typeSpecifier.ret); }
		declarator
		{
			$type = TypeAnalyser.analyse();
			$name = $declarator.name;
		} #parameterDeclaration2
	|	t3 = typeSpecifier { TypeAnalyser.enter($typeSpecifier.ret); }
		abstractDeclarator
		{
			$type = TypeAnalyser.analyse();
			$name = "";
		} #parameterDeclaration3
	;

abstractDeclarator
locals [int n = 0]
@after {
	for (int i = 0; i < $n; ++i)
		TypeAnalyser.addStar();
}
	:	('*' { ++$n; } )+
	|	('*' { ++$n; } )*
		directAbstractDeclarator
	;

directAbstractDeclarator
	:	'(' abstractDeclarator ')'
	|	'[' ']'
			{ TypeAnalyser.addArray(null); }
	|	'[' constantExpression ']'
			{ TypeAnalyser.addArray($constantExpression.ret); }
	|	'(' ')'
			{ TypeAnalyser.addParameter(); }
	|	'(' parameterTypeList ')'
			{ TypeAnalyser.addParameter($parameterTypeList.types, $parameterTypeList.names, $parameterTypeList.hasVaList); }
	|	directAbstractDeclarator '[' ']'
			{ TypeAnalyser.addArray(null); }
	|	directAbstractDeclarator '[' constantExpression ']'
			{ TypeAnalyser.addArray($constantExpression.ret); }
	|	directAbstractDeclarator '(' ')'
			{ TypeAnalyser.addParameter(); }
	|	directAbstractDeclarator '(' parameterTypeList? ')'
			{ TypeAnalyser.addParameter($parameterTypeList.types, $parameterTypeList.names, $parameterTypeList.hasVaList); }
	;

typedefName returns [Type ret]
	:	{ Environment.isTypedefName(_input.LT(1).getText()) }? Identifier
		{ $ret = (Type)Environment.symbolNames.queryName($Identifier.text).ref; }
	;

initializer returns [SimpleInitializerList ret]
	: assignmentExpression { $ret = new SimpleInitializerList($assignmentExpression.ret); }
		#initializer1
	|	L3 i1 = initializer
			{
				$ret = new SimpleInitializerList(new ArrayList<SimpleInitializerList>());
				$ret.list.add($i1.ret);
			}
			(Comma i2 = initializer { $ret.list.add($i2.ret); })*
		R3
		#initializer2
	;

/* Statements */
statement returns [Statement ret]
	: expressionStatement { $ret = $expressionStatement.ret; }
	| compoundStatement[null, null]  { $ret = $compoundStatement.ret; }
	| selectionStatement  { $ret = $selectionStatement.ret;  }
	| iterationStatement  { $ret = $iterationStatement.ret; }
	| jumpStatement	  { $ret = $jumpStatement.ret; }
	;

expressionStatement returns [Statement ret = null]
	: (expression { $ret = $expression.ret; })? ';'
	;

compoundStatement[ArrayList<Type> toDefineTypes, ArrayList<String> toDefineNames] returns [CompoundStatement ret]
locals [ ArrayList<Statement> statements = new ArrayList<Statement>(), ArrayList<Integer> givenVariables = new ArrayList<>(), ArrayList<Integer> parameters = new ArrayList<>() ]
	: L3
			{
				Environment.enterScope();
				if ($toDefineTypes != null) {
					int n = $toDefineTypes.size();
					for (int i = 0; i < n; ++i) {
						int uId = Environment.symbolNames.defineVariable($toDefineNames.get(i), $toDefineTypes.get(i));
						$givenVariables.add(uId);
						$parameters.add(uId);
					}
				}
			}
		(
			declaration
		|
			(statement { $statements.add($statement.ret); } )
		|
			functionDefinition
		)*
	  R3
			{
				$ret = new CompoundStatement(Environment.symbolNames.getVariablesInCurrentScope(), $statements, $givenVariables, $parameters);
				Environment.exitScope();
			}
	;

selectionStatement returns [IfStatement ret]
locals [ Expression e1 = null, Statement s1 = null, Statement s2 = null ]
	: If L1 expression { $e1 = $expression.ret; } R1 st1 = statement { $s1 = $st1.ret; }
		(Else st2 = statement { $s2 = $st2.ret; } )?
		{
			$ret = new IfStatement($e1, $s1, $s2);
		}
	;

iterationStatement returns [Statement ret]
locals [WhileStatement whileS, ForStatement forS, Expression e1 = null, Expression e2 = null, Expression e3]
	: While L1 expression R1
			{
				$whileS = new WhileStatement($expression.ret);
				Environment.loopStack.push($whileS);
			}
		statement
			{
				$whileS.a = $statement.ret;
				Environment.loopStack.pop();
				$ret = $whileS;
			} #iterationStatement1
	| For L1 (ex1 = expression {$e1 = $ex1.ret;} )? Semi
			 (ex2 = expression {$e2 = $ex2.ret;} )? Semi
			 (ex3 = expression {$e3 = $ex3.ret;} )?
			R1
			{
				$forS = new ForStatement($e1, $e2, $e3);
				Environment.loopStack.push($forS);
			}
		statement
			{
				$forS.d = $statement.ret;
				Environment.loopStack.pop();
				$ret = $forS;
			} #iterationStatement2
	;

jumpStatement returns [Statement ret]
locals [ Expression e = null ]
	: 'continue' ';'
		{
			$ret = new ContinueStatement(Environment.getTopLoop());
		} #jumpStatement1
	| 'break' ';'
		{
			$ret = new BreakStatement(Environment.getTopLoop());
		} #jumpStatement2
	| 'return' (expression {$e = $expression.ret;} )? ';'
		{
			if ($e != null)
				Environment.matchReturn($e.type);
			else
				Environment.matchReturn(VoidType.instance);
			$ret = new ReturnStatement($e);
		} #jumpStatement3
	;

/* Expressions  */
expression returns [Expression ret]
	: a1 = assignmentExpression   { $ret = $a1.ret; }
		(Comma a2 = assignmentExpression
			{ $ret = CommaExpression.getExpression($ret, $a2.ret);  }
		)*
	;

assignmentExpression returns [Expression ret]
	: logicalOrExpression { $ret = $logicalOrExpression.ret; } #assignmentExpression1
	| a = unaryExpression assignmentOperator b = assignmentExpression
				{ $ret = Assign.getExpression($a.ret, $b.ret, $assignmentOperator.text); } #assignmentExpression2
	| 'va_start' '(' ap = Identifier ',' prev = Identifier ')'
		{
			if (!Environment.isVariable($ap.text))
				throw new CompilationError($ap.text + " is not defined.");
			if (!Environment.isVariable($prev.text))
				throw new CompilationError($prev.text + " is not defined.");
			$ret = Assign.getExpression(
				IdentifierExpression.getExpression($ap.text),
				Add.getExpression(
					CastExpression.getExpression(
						IntType.instance,
						AddressFetch.getExpression(
							IdentifierExpression.getExpression($prev.text)
						)
					),
					new IntConstant(Panel.getPointerSize())
				),
				"="
			);
		}
	#assignmentExpression3
	;

assignmentOperator
	: '=' | '*=' | '/=' | '%=' | '+=' | '-=' | '<<=' | '>>=' | '&=' | '^=' | '|='
	;

constantExpression returns [Expression ret]
	: logicalOrExpression
		{
			$ret = $logicalOrExpression.ret;
			if (!($ret instanceof Constant))
				throw new CompilationError("Not constant.");
		}
	;

logicalOrExpression returns [Expression ret]
	: a1 = logicalAndExpression { $ret = $a1.ret; }
		(OrOr a2 = logicalAndExpression
			{ $ret = LogicalOr.getExpression($ret, $a2.ret); }
		)*
	;

logicalAndExpression returns [Expression ret]
	: a1 = inclusiveOrExpression  { $ret = $a1.ret; }
		(AndAnd a2 = inclusiveOrExpression
			{ $ret = LogicalAnd.getExpression($ret, $a2.ret);  }
		)*
	;

inclusiveOrExpression returns [Expression ret]
	: a1 = exclusiveOrExpression   { $ret = $a1.ret; }
		(Or a2 = exclusiveOrExpression
			{ $ret = BitwiseOr.getExpression($ret, $a2.ret); }
		)*
	;

exclusiveOrExpression returns [Expression ret]
	: a1 = andExpression   { $ret = $a1.ret; }
		(Caret a2 = andExpression
			{ $ret = BitwiseXOR.getExpression($ret, $a2.ret); }
		)*
	;

andExpression returns [Expression ret]
	: a1 = equalityExpression   { $ret = $a1.ret; }
		(And a2 = equalityExpression
			{ $ret = BitwiseAnd.getExpression($ret, $a2.ret); }
		)*
	;

equalityExpression returns [Expression ret]
	: a1 = relationalExpression   { $ret = $a1.ret; }
		(op = equalityOperator a2 = relationalExpression
			{
				if ($op.text.equals("=="))
					$ret = EqualTo.getExpression($ret, $a2.ret);
				else
					$ret = NotEqualTo.getExpression($ret, $a2.ret);
			}
		)*
	;

equalityOperator
	: '==' | '!='
	;

relationalExpression returns [Expression ret]
	: a1 = shiftExpression   { $ret = $a1.ret; }
		(op = relationalOperator a2 = shiftExpression
			{
				if ($op.text.equals("<"))
					$ret = LessThan.getExpression($ret, $a2.ret);
				else if ($op.text.equals(">"))
					$ret = GreaterThan.getExpression($ret, $a2.ret);
				else if ($op.text.equals("<="))
					$ret = LE.getExpression($ret, $a2.ret);
				else
					$ret = GE.getExpression($ret, $a2.ret);
			}
		)*
	;

relationalOperator
	: '<' | '>' | '<=' | '>='
	;

shiftExpression returns [Expression ret]
	: a1 = additiveExpression { $ret = $a1.ret; }
		(op = shiftOperator a2 = additiveExpression
			{
				if ($op.text.equals("<<"))
					$ret = ShiftLeft.getExpression($ret, $a2.ret);
				else
					$ret = ShiftRight.getExpression($ret, $a2.ret);
			}
		)*
	;

shiftOperator
	: '<<' | '>>'
	;

additiveExpression returns [Expression ret]
	: a1 = multiplicativeExpression { $ret = $a1.ret; }
		(op = additiveOperator a2 = multiplicativeExpression
			{
				if ($op.text.equals("+"))
					$ret = Add.getExpression($ret, $a2.ret);
				else
					$ret = Subtract.getExpression($ret, $a2.ret);
			}
		)*
	;

additiveOperator
	: '+' | '-'
	;

multiplicativeExpression returns [Expression ret]
	: a1 = castExpression { $ret = $castExpression.ret; }
		(op = multiplicativeOperator a2 = castExpression
			{
				if ($op.text.equals("*"))
					$ret = Multiply.getExpression($ret, $a2.ret);
				else if ($op.text.equals("/"))
					$ret = Divide.getExpression($ret, $a2.ret);
				else
					$ret = Modulo.getExpression($ret, $a2.ret);
			}
		)*
	;

multiplicativeOperator
	: '*' | '/' | '%'
	;

castExpression returns [Expression ret]
	: unaryExpression { $ret = $unaryExpression.ret; } #castExpression1
	| L1 typeName R1 c1 = castExpression
		{
			$ret = CastExpression.getExpression($typeName.ret, $c1.ret);
		} #castExpression2
	;

typeName returns [Type ret]
@after {
	TypeAnalyser.exit();
}
	:	typeSpecifier
		{
			TypeAnalyser.enter($typeSpecifier.ret);
			$ret = $typeSpecifier.ret;
		} #typeName1
	|	typeSpecifier { TypeAnalyser.enter($typeSpecifier.ret); }
		abstractDeclarator
		{
			$ret = TypeAnalyser.analyse();
		} #typeName2
	;

unaryExpression returns [Expression ret]
	: postfixExpression { $ret = $postfixExpression.ret; } #unaryExpression1
	| '++' u1 = unaryExpression { $ret = PrefixSelfInc.getExpression($u1.ret); } #unaryExpression2
	| '--' u2 = unaryExpression { $ret = PrefixSelfDec.getExpression($u2.ret); } #unaryExpression3
	| op = unaryOperator a2 = castExpression
		{
			if ($op.text.equals("&"))
				$ret = AddressFetch.getExpression($a2.ret);
			else if ($op.text.equals("*"))
				$ret = AddressAccess.getExpression($a2.ret);
			else if ($op.text.equals("+"))
				$ret = Positive.getExpression($a2.ret);
			else if ($op.text.equals("-"))
				$ret = Negative.getExpression($a2.ret);
			else if ($op.text.equals("~"))
				$ret = BitwiseNot.getExpression($a2.ret);
			else if ($op.text.equals("!"))
				$ret = LogicalNot.getExpression($a2.ret);
		}
		#unaryExpression4
	| SizeOf '(' Identifier ')'
		{
			if (Environment.isVariable($Identifier.text))
				$ret = new Sizeof(IdentifierExpression.getExpression($Identifier.text));
			else if (Environment.isTypedefName($Identifier.text))
				$ret = new IntConstant(Environment._pretend_being_private_sizeof);
			else
				throw new CompilationError("Unknow " + $Identifier.text);
		} #unaryExpression5
	| SizeOf '(' typeName ')' { $ret = new IntConstant($typeName.ret.sizeof()); } #unaryExpression6
	| SizeOf u3 = unaryExpression { $ret = new Sizeof($u3.ret); } #unaryExpression7
	| 'va_arg' '(' ap = Identifier ',' typeName ')'
		{
			if (!Environment.isVariable($ap.text))
				throw new CompilationError($ap.text + " is not defined.");
			$ret = ArrayAccess.getExpression(
				CastExpression.getExpression(
					new VariablePointerType($typeName.ret),
					Subtract.getExpression(
						Assign.getExpression(
							IdentifierExpression.getExpression($ap.text),
							new IntConstant(Panel.getPointerSize()),
							"+="
						),
						new IntConstant(Panel.getPointerSize())
					)
				),
				new IntConstant(0)
			);
		} #unaryExpression8
	;

unaryOperator
	: '&' | '*' | '+' | '-' | '~' | '!'
	;

postfixExpression returns [Expression ret]
locals [ ArrayList<Expression> arg = null ]
	: primaryExpression { $ret = $primaryExpression.ret; }
	| p = postfixExpression '[' expression ']' { $ret = ArrayAccess.getExpression($p.ret, $expression.ret); }
	| p = postfixExpression '(' (arguments { $arg = $arguments.ret; } )? ')' { $ret = FunctionCall.getExpression($p.ret, $arg); }
	| p = postfixExpression '.' Identifier { $ret = MemberAccess.getExpression($p.ret, $Identifier.text); }
	| p = postfixExpression '->' Identifier  { $ret = PointerMemberAccess.getExpression($p.ret, $Identifier.text); }
	| p = postfixExpression '++' { $ret = PostfixSelfInc.getExpression($p.ret); }
	| p = postfixExpression '--' { $ret = PostfixSelfDec.getExpression($p.ret); }
	;

arguments returns [ArrayList<Expression> ret ]
@init {
	$ret = new ArrayList<Expression>();
}
	: a1 = assignmentExpression { $ret.add($a1.ret); }
		(Comma a2 = assignmentExpression
			{
				$ret.add($a2.ret);
			}
		)*
	;

primaryExpression returns [Expression ret]
locals [ ArrayList<String> s ]
@init {
	$s = new ArrayList<String>();
}
	: { Environment.isVariable(_input.LT(1).getText()) }? Identifier
		{
			$ret = IdentifierExpression.getExpression($Identifier.text);
		} #primaryExpression1
	| constant
		{
			$ret = $constant.ret;
		} #primaryExpression2
	| (StringLiteral
		{
			$s.add($StringLiteral.text);
		}
	  )+
		{
			$ret = StringConstant.getExpression($s);
		} #primaryExpression3
	| '(' expression ')'
		{
			$ret = $expression.ret;
		} #primaryExpression4
	| lambdaExpression
		{
			$ret = $lambdaExpression.ret;
		} #primaryExpression5
	;

lambdaExpression returns [Expression ret]
locals [ Type type = null, CompoundStatement s = null, ArrayList<Type> parameterTypes, ArrayList<String> parameterNames, boolean hasVaList = false, int uId = -1, Stack<Loop> loopStack = null]
@init {
	$parameterTypes = new ArrayList<Type>();
	$parameterNames = new ArrayList<String>();
	$loopStack = Environment.loopStack;
	Environment.loopStack = new Stack<>();
}
@after {
	Environment.loopStack = $loopStack;
}
	:
	L2 R2
		L1 (parameterTypeList
			{
				$parameterTypes = $parameterTypeList.types;
				$parameterNames = $parameterTypeList.names;
				$hasVaList = $parameterTypeList.hasVaList;
				if ($parameterNames.size() != 0 && (new HashSet<>($parameterNames).size()) != $parameterNames.size())
					throw new CompilationError("parameter should have different names.");
				for (String name : $parameterNames)
					if (name == null || name.equals(""))
						throw new CompilationError("No parameter name.");
			}
		)? R1
		(POINTER typeName
			{
				$type = $typeName.ret;
			}
		)?
		{
			Environment.functionReturnStack.push($type);
			if ($type == null) $type = VoidType.instance;
			$type = new FunctionType($type, $parameterTypes, $parameterNames, $hasVaList);
			$uId = Environment.symbolNames.defineLocalFunction("", $type);
		}
		compoundStatement[$parameterTypes, $parameterNames]
		{
			$s = $compoundStatement.ret;
			Environment.symbolNames.defineVariable($uId, $type, $s);
			$s.youAreAFrame(Environment.symbolNames.currentScope + 1);
			Environment.functionReturnStack.pop();
			$ret = IdentifierExpression.getExpression($uId);
		}
	;

constant returns [Expression ret]
	: DecimalConstant { $ret = IntConstant.getExpression($DecimalConstant.text, 10); }
	| OctalConstant { $ret = IntConstant.getExpression($OctalConstant.text, 8); }
	| HexadecimalConstant { $ret = IntConstant.getExpression($HexadecimalConstant.text, 16);  }
	| CharacterConstant { $ret = CharConstant.getExpression($CharacterConstant.text); }
	;

// Lexer

Typedef : 'typedef';
Semi : ';';
Comma : ',';
L1 : '(';
R1 : ')';
L2 : '[';
R2 : ']';
L3 : '{';
R3 : '}';
EQ : '=';
STAR : '*';
If : 'if';
Else : 'else';
While : 'while';
For : 'for';
OrOr : '||';
AndAnd : '&&';
Or : '|';
Caret : '^';
And : '&';
SizeOf : 'sizeof';
POINTER : '->';

Identifier
	:	IdentifierNondigit
		(	IdentifierNondigit
		|	Digit
		)*
	;

fragment
IdentifierNondigit
	:	Nondigit
	;

fragment
Nondigit
	:	[a-zA-Z_$]
	;

fragment
Digit
	:	[0-9]
	;

fragment
HexQuad
	:	HexadecimalDigit HexadecimalDigit HexadecimalDigit HexadecimalDigit
	;

DecimalConstant
	:	NonzeroDigit Digit*
	;

OctalConstant
	:	'0' OctalDigit*
	;

HexadecimalConstant
	:	HexadecimalPrefix HexadecimalDigit+
	;

fragment
HexadecimalPrefix
	:	'0' [xX]
	;

fragment
NonzeroDigit
	:	[1-9]
	;

fragment
OctalDigit
	:	[0-7]
	;

fragment
HexadecimalDigit
	:	[0-9a-fA-F]
	;

fragment
Sign
	:	'+' | '-'
	;

fragment
DigitSequence
	:	Digit+
	;

CharacterConstant
	:	'\'' CCharSequence '\''
	;

fragment
CharSequence
	:	Char+
	;

fragment
Char
	:	~['\\\r\n]
	|	EscapeSequence
	;

fragment
EscapeSequence
	:	SimpleEscapeSequence
	|	OctalEscapeSequence
	|	HexadecimalEscapeSequence
	;

fragment
SimpleEscapeSequence
	:	'\\' ['"?abfnrtv\\]
	;

fragment
OctalEscapeSequence
	:	'\\' OctalDigit
	|	'\\' OctalDigit OctalDigit
	|	'\\' OctalDigit OctalDigit OctalDigit
	;

fragment
HexadecimalEscapeSequence
	:	'\\x' HexadecimalDigit+
	;

StringLiteral
	:	'"' SCharSequence? '"'
	;

fragment
SCharSequence
	:	SChar+
	;

fragment
SChar
	:   ~["\\\r\n]
	|   EscapeSequence
	;

fragment
CCharSequence
	:	CChar+
	;

fragment
CChar
	:	~['\\\r\n]
	|	EscapeSequence
	;

Preprocessing
	:	'#' ~[\r\n]* ('\r' | '\n' | ('\r''\n'))
		-> channel(HIDDEN)
	;

Whitespace
	:	[ \t]+
		-> skip
	;

Newline
	:	(	'\r' '\n'?
		|	'\n'
		)
		-> skip
	;

BlockComment
	:	'/*' .*? '*/'
		-> channel(HIDDEN)
	;

LineComment
	:	'//' ~[\r\n]*
		-> channel(HIDDEN)
	;
