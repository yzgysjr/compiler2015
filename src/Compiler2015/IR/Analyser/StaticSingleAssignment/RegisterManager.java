package Compiler2015.IR.Analyser.StaticSingleAssignment;

import Compiler2015.Environment.Environment;
import Compiler2015.Exception.CompilationError;
import Compiler2015.IR.CFG.CFGVertex;
import Compiler2015.Utility.Tokens;

import java.util.*;

public class RegisterManager {
	public static HashMap<Integer, RegisterManagerEntry> manager;
	public static CFGVertex root;

	public static void init(ArrayList<Integer> predefined, CFGVertex root) {
		RegisterManager.manager = new HashMap<>();
		RegisterManager.root = root;
		predefined.add(0); // add memory
		for (Integer x : predefined)
			manager.put(x, new RegisterManagerEntry() {{
				defsite.add(root);
			}});
		Environment.symbolNames.table.stream()
				.filter(e -> e != null && e.scope == 1 && (e.type == Tokens.VARIABLE || e.type == Tokens.STRING_CONSTANT))
				.forEach(e -> manager.put(e.uId, new RegisterManagerEntry() {{
					defsite.add(root);
				}}));
	}

	public static void addVariable(int uId, CFGVertex site) {
		if (uId == -1)
			return;
//		System.out.printf("uId = %d, site = %s\n", uId, site == null ? "null" : site.id);
		if (!manager.containsKey(uId)) {
			manager.put(uId, new RegisterManagerEntry());
		}
		if (site != null)
			manager.get(uId).defsite.add(site);
		else
			++manager.get(uId).useCnt;
	}

	public static void checkDefSite() {
		manager.entrySet().stream().forEach(e -> {
			if (e.getValue().defsite.isEmpty())
				throw new CompilationError("Internal Error.");
		});
	}

	public static void insertPhi() {
		for (Map.Entry<Integer, RegisterManagerEntry> entry : manager.entrySet()) {
			int a = entry.getKey();
//			if (entry.getUId().defsite.size() == 1 && entry.getUId().useCnt <= 1)
//				continue;
//			System.out.printf("a = %d, defsite = %s\n", a, entry.getUId().defsite.toString());
			Stack<CFGVertex> w = new Stack<>();
			w.addAll(entry.getValue().defsite);
			while (!w.isEmpty()) {
				CFGVertex n = w.pop();
				n.dominanceFrontier.stream().filter(np -> !np.phis.containsKey(a)).forEach(np -> {
					np.addPhi(a);
					if (!entry.getValue().defsite.contains(np))
						w.push(np);
				});
			}
		}
	}

	public static int getPeek(int x) {
		return manager.get(x).stack.peek();
	}

	public static class RegisterManagerEntry {
		public HashSet<CFGVertex> defsite = new HashSet<>();
		public int count = 0;
		public int useCnt = 0;
		public Stack<Integer> stack = new Stack<Integer>() {{
			add(0);
		}};
	}
}