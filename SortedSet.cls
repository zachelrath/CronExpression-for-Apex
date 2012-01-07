public class SortedSet {
	
	//
	// NOTE: This only works with PRIMITIVES, i.e. Integers, Strings, etc. 
	//
	
	private Map<Object,Node> nodesByValue;
	private Map<Integer,Node> nodesByOrder;
	private Integer size;
	
	public SortedSet() {
		this.nodesByOrder = new Map<Integer,Node>();
		this.nodesByValue = new Map<Object,Node>();
		this.size = 0; 
	}
	
	public class Node {
		public Entry entry { public get; private set; }
		public Integer order { public get; private set; }
		public Node(Entry e, Integer order) {
			this.entry = e;
			this.order = order;
		}
		public Object value() { return entry.value; }
	}
	
	public Boolean add(Entry e) {
		// Make sure that the Map does not contain the specified element
		if (!nodesByValue.containsKey(e.value)) {
			// Instantiate a new Node
			Node n = new Node(e,size++);
			nodesByOrder.put(n.order,n);
			nodesByValue.put(e.value,n);
			return true;
		} else return false;
	}
	
	// @Override
	public Boolean add(Object o) {
		// Make sure that the Map does not contain the specified element
		if (!nodesByValue.containsKey(o)) return add(new Entry(o));
		else return false;	
	}
	
	// @Override
	public Boolean addAll(List<Object> l) {
		Boolean addedAll = true;
		for (Object o : l) {
			if (!nodesByValue.containsKey(o)) add(o);
			else if (addedAll == true) addedAll = false;
		}
		return addedAll;
	}
	
	// @Override
	public Boolean addAll(Set<Object> l) {
		Boolean addedAll = true;
		for (Object o : l) {
			if (!nodesByValue.containsKey(o)) add(o);
			else if (addedAll == true) addedAll = false;
		}
		return addedAll;
	} 
	
	// @Override
	public Boolean addAll(List<Entry> entries) {
		Boolean addedAll = true;
		for (Entry e : entries) {
			if (!nodesByValue.containsKey(e.value)) add(e);
			else if (addedAll == true) addedAll = false;
		}
		return addedAll;
	}
	
	// Empty out our Sorted Set
	// @Override
	public void clear() {
		size = 0;
		nodesByValue.clear();
		nodesByOrder.clear();
	}
	
	// @Override
	public SortedSet deepClone() {
		SortedSet newSS = new SortedSet();
		newSS.addAll(entryList());
		return newSS;
	}
	
	// @Override
	public Boolean contains(Object e) {
		return nodesByValue.containsKey(e);
	}
	
	// @Override
	public Boolean isEmpty() {
		return size == 0;
	}
	
	// Return a List view of all the entries in our set
	public List<Entry> entryList() {
		List<Entry> entries = new List<Entry>();
		for (Integer i = 0; i < size; i++) entries.add(nodesByOrder.get(i).entry);
		return entries;
	}
	
	// Remove the entry with the specified order
	// @Override
	public Object remove(Integer order) {
		if (!nodesByOrder.containsKey(order)) {
			// Remove the Node from nodesByOrder
			Node n = nodesByOrder.remove(order);
			// Remove this Node from nodesByValue 
			nodesByValue.remove(n.value());
			// Decrement size
			size--;
			// Return the value
			return n.value();
		} else return null;
	}
	
	// Remove the entry with the specified value
	// @Override
	public Object remove(Object o) {
		if (!nodesByValue.containsKey(o)) {
			// Remove the Node from nodesByValue
			Node n = nodesByValue.remove(o);
			// Remove this Node from nodesByOrder 
			nodesByOrder.remove(n.order);
			// Decrement size
			size--;
			// Return the value
			return n.value();
		} else return null;
	}
	
	//
	// SORTED SET INTERFACE METHODS
	//
	
	// Return the last element in the Set
	public Object last() { return nodesByOrder.get(size-1).value(); }
	// Return the first element in the Set
	public Object first() { return nodesByOrder.get(0).value(); }
	// Returns a view of the portion of this set whose elements are strictly less than toElement.
	public SortedSet headSet(Object toElement) {
		// Find the entry corresponding to toElement 
		Node endNode = nodesByValue.get(toElement);
		if (endNode == null) return null;
		Integer endIndex = endNode.order;
		
		// Instantiate a new SortedSet to return to the user
		SortedSet headset = new SortedSet();
		
		for (Integer i = 0; i < endIndex; i++) headset.add(nodesByOrder.get(i).entry);
		
		return headset;
	}
	// Returns a view of the portion of this set whose elements are greater than or equal to fromElement.
	public SortedSet tailSet(Object fromElement) {
		// Find the entry corresponding to fromElement 
		Node startNode = nodesByValue.get(fromElement);
		if (startNode == null) return null;
		Integer startIndex = startNode.order;
		
		// Instantiate a new SortedSet to return to the user
		SortedSet tailset = new SortedSet();
		
		for (Integer i = startIndex; i < size; i++) tailset.add(nodesByOrder.get(i).entry);
		
		return tailset;
	}
	// Returns a view of the portion of this set whose elements range 
	// from fromElement (inclusive = fromInclusive) 
	// to toElement (inclusive = toInclusive). 
	public SortedSet subSet(Object fromElement, boolean fromInclusive, Object toElement, boolean toInclusive) {
		// Find the entry corresponding to fromElement 
		Node startNode = nodesByValue.get(fromElement);
		// Find the entry corresponding to toElement 
		Node endNode = nodesByValue.get(toElement); 
		if (startNode == null || endNode == null) return null;
		Integer startIndex = startNode.order + (fromInclusive ? 0 : 1);
		Integer endIndex = endNode.order + (toInclusive ? 1 : 0);
		
		// Instantiate a new SortedSet to return to the user
		SortedSet subset = new SortedSet();
		
		for (Integer i = startIndex; i < endIndex; i++) subset.add(nodesByOrder.get(i).entry);
		
		return subset;
	}
	
	// @Override
	public Integer size() {
		return size;
	}
	
	public class Entry {
		//public Integer order;
		public Object value;
		public Entry(Object value) {
			this.value = value;
		}
	}
	
	
}