/*******************************************************************************

        copyright:      Copyright (c) 2007-2008 Jascha Wetzel. All rights reserved.

        license:        BSD style: $(LICENSE)

        version:        Initial release: Jan 2008

        authors:        Jascha Wetzel

        Regular expression engine based on tagged NFA/DFA method.

*******************************************************************************/
module tango.text.Regex;

/*******************************************************************************
    A simple pair
*******************************************************************************/
private struct Pair(T)
{
    static Pair opCall(T a, T b)
    {
        Pair p;
        p.a = a;
        p.b = b;
        return p;
    }

    union
    {
        struct {
            T first, second;
        }
        struct {
            T a, b;
        }
    }
}

/*******************************************************************************
    Double linked list
*******************************************************************************/
private class List(T)
{
    class Element
    {
        T value;
        Element prev,
                next;

        this(T v)
        {
            value = v;
        }
    }

    size_t  len;
    Element head,
            tail;

    List opCatAssign(T v)
    {
        if ( tail is null )
            head = tail = new Element(v);
        else {
            tail.next = new Element(v);
            tail.next.prev = tail;
            tail = tail.next;
        }
        ++len;
        return this;
    }

    List insertAfter(T w, T v)
    {
        foreach ( e; &this.elements )
        {
            if ( e.value is w )
                return insertAfter(e, v);
        }
        return null;
    }

    List insertAfter(Element e, T v)
    {
        auto tmp = new Element(v);
        tmp.prev = e;
        tmp.next = e.next;
        e.next.prev = tmp;
        e.next = tmp;
        if ( e is tail )
            tail = tmp;
        ++len;
        return this;
    }

    List opCatAssign(List l)
    {
        if ( l.empty )
            return this;
        if ( tail is null ) {
            head = l.head;
            tail = l.tail;
        }
        else {
            tail.next = l.head;
            tail.next.prev = tail;
            tail = l.tail;
        }
        len += l.len;
        return this;
    }

    List pushFront(T v)
    {
        if ( head is null )
            head = tail = new Element(v);
        else
        {
            head.prev = new Element(v);
            head.prev.next = head;
            head = head.prev;
        }
        ++len;
        return this;
    }

    List insertBefore(T w, T v)
    {
        foreach ( e; &this.elements )
        {
            if ( e.value is w )
                return insertBefore(e, v);
        }
        return null;
    }

    List insertBefore(Element e, T v)
    {
        auto tmp = new Element(v);
        tmp.prev = e.prev;
        tmp.next = e;
        e.prev.next = tmp;
        e.prev = tmp;
        if ( e is head )
            head = tmp;
        ++len;
        return this;
    }

    List pushFront(List l)
    {
        if ( l.empty )
            return this;
        if ( head is null ) {
            head = l.head;
            tail = l.tail;
        }
        else {
            head.prev = l.tail;
            head.prev.next = head;
            head = l.head;
        }
        len += l.len;
        return this;
    }

    size_t length()
    {
        return len;
    }

    bool empty()
    {
        return head is null;
    }

    void clear()
    {
        head = null;
        tail = null;
        len = 0;
    }

    void pop()
    {
        remove(tail);
    }

    void remove(Element e)
    {
        if ( e is null )
            return;
        if ( e.prev is null )
            head = e.next;
        else
            e.prev.next = e.next;
        if ( e.next is null )
            tail = e.prev;
        else
            e.next.prev = e.prev;
        --len;
    }

    int elements(int delegate(inout Element) dg)
    {
        for ( Element e=head; e !is null; e = e.next )
        {
            int ret = dg(e);
            if ( ret )
                return ret;
        }
        return 0;
    }

    int elements_reverse(int delegate(inout Element) dg)
    {
        for ( Element e=tail; e !is null; e = e.prev )
        {
            int ret = dg(e);
            if ( ret )
                return ret;
        }
        return 0;
    }

    int opApply(int delegate(inout T) dg)
    {
        for ( Element e=head; e !is null; e = e.next )
        {
            int ret = dg(e.value);
            if ( ret )
                return ret;
        }
        return 0;
    }

    int opApplyReverse(int delegate(inout T) dg)
    {
        for ( Element e=tail; e !is null; e = e.prev )
        {
            int ret = dg(e.value);
            if ( ret )
                return ret;
        }
        return 0;
    }
}

/*******************************************************************************
    Stack based on dynamic array
*******************************************************************************/
private struct Stack(T)
{
    size_t  _top;
    T[]     stack;

    void push(T v)
    {
        if ( _top >= stack.length )
            stack.length = stack.length*2+1;
        stack[_top] = v;
        ++_top;
    }
    alias push opCatAssign;

    void opCatAssign(T[] vs)
    {
        size_t end = _top+vs.length;
        if ( end > stack.length )
            stack.length = end*2;
        stack[_top..end] = vs;
        _top = end;
    }

    void pop(size_t num)
    {
        assert(_top>=num);
        _top -= num;
    }

    T pop()
    {
        assert(_top>0);
        return stack[--_top];
    }

    T top()
    {
        assert(_top>0);
        return stack[_top-1];
    }

    T* topPtr()
    {
        assert(_top>0);
        return &stack[_top-1];
    }

    bool empty()
    {
        return _top == 0;
    }

    void clear()
    {
        _top = 0;
    }

    size_t length()
    {
        return _top;
    }

    T[] array()
    {
        return stack[0.._top];
    }

    T opIndex(size_t i)
    {
        return stack[i];
    }

    Stack dup()
    {
        Stack s;
        s._top = _top;
        s.stack = stack.dup;
        return s;
    }
}

/**************************************************************************************************
    Set container based on assoc array
**************************************************************************************************/
private struct Set(T)
{
    bool[T] data;

    static Set opCall()
    {
        Set s;
        return s;
    }

    static Set opCall(T v)
    {
        Set s;
        s ~= v;
        return s;
    }
    
    void opAddAssign(T v)
    {
        data[v] = true;
    }
    
    void opAddAssign(Set s)
    {
        foreach ( v; s.elements )
            data[v] = true;
    }
    alias opAddAssign opCatAssign;
    
    size_t length()
    {
        return data.length;
    }
    
    T[] elements()
    {
        return data.keys;
    }

    bool remove(T v)
    {
        if ( (v in data) is null )
            return false;
        data.remove(v);
        return true;
    }
    
    bool contains(T v)
    {
        return (v in data) !is null;
    }
    
    bool contains(Set s)
    {
        Set tmp = s - *this;
        return tmp.empty;
    }

    bool empty()
    {
        return data.length==0;
    }

    Set opSub(Set s)
    {
        Set res = dup;
        foreach ( v; s.elements )
            res.remove(v);
        return res;
    }

    Set dup()
    {
        Set s;
        foreach ( v; data.keys )
            s.data[v] = true;
        return s;
    }
}
import tango.math.Math;

/**************************************************************************************************
    A range of characters
**************************************************************************************************/
private struct CharRange(char_t)
{
    char_t  l, r;

    static CharRange opCall(char_t c)
    {
        CharRange r;
        r.l = c;
        r.r = c;
        return r;
    }

    static CharRange opCall(char_t a, char_t b)
    {
        CharRange r;
        r.l = min(a,b);
        r.r = max(a,b);
        return r;
    }

    int opCmp(CharRange cr)
    {
        if ( l == cr.l )
            return 0;
        if ( l < cr.l )
            return -1;
        return 1;
    }

    bool contains(char_t c)
    {
        return c >= l && c <= r;
    }

    bool contains(CharRange cr)
    {
        return l <= cr.l && r >= cr.r;
    }

    bool intersects(CharRange cr)
    {
        return r >= cr.l && l <= cr.r;
    }

    CharRange intersect(CharRange cr)
    {
        assert(intersects(cr));
        CharRange ir;
        ir.l = max(l, cr.l);
        ir.r = min(r, cr.r);
        return ir;
    }

    CharRange[] subtract(CharRange cr)
    {
        CharRange[] sr;
        if ( cr.contains(*this) )
            return sr;
        if ( !intersects(cr) )
            sr ~= *this;
        else
        {
            CharRange d;
            if ( contains(cr) )
            {
                d.l = l;
                d.r = cr.l-1;
                if ( d.l <= d.r )
                    sr ~= d;
                d.l = cr.r+1;
                d.r = r;
                if ( d.l <= d.r )
                    sr ~= d;
            }
            else if ( cr.r > l )
            {
                d.l = cr.r+1;
                d.r = r;
                if ( d.l <= d.r )
                    sr ~= d;
            }
            else if ( cr.l < r )
            {
                d.l = l;
                d.r = cr.l-1;
                if ( d.l <= d.r )
                    sr ~= d;
            }
        }
        return sr;
    }

    string toString()
    {
        char[] str;
        auto layout = new Layout!(char);
        if ( l == r )
        {
            if ( l > 0x20 && l < 0x7f )
                encode(str, l);
            else
                str = "("~layout.convert("{:x}", cast(int)l)~")";
        }
        else
        {
            if ( l > 0x20 && l < 0x7f )
                encode(str, l);
            else
                str ~= "("~layout.convert("{:x}", cast(int)l)~")";
            str ~= "-";
            if ( r > 0x20 && r < 0x7f )
                encode(str, r);
            else
                str ~= "("~layout.convert("{:x}", cast(int)r)~")";
        }
        return str;
    }
}

/**************************************************************************************************
    Represents a class of characters as used in regular expressions (e.g. [0-9a-z], etc.)
**************************************************************************************************/
struct CharClass(char_t)
{
    alias CharRange!(char_t) range_t;

    //---------------------------------------------------------------------------------------------
    // pre-defined character classes
    static const CharClass!(char_t)
        line_startend = {parts: [
            {l:0x00, r:0x00},
            {l:0x0a, r:0x0a},
            {l:0x13, r:0x13}
        ]},
        digit = {parts: [
            {l:0x30, r:0x39}
        ]},
        whitespace = {parts: [
            {l:0x00, r:0x00},
            {l:0x09, r:0x09},
            {l:0x0a, r:0x0a},
            {l:0x0b, r:0x0b},
            {l:0x13, r:0x13},
            {l:0x14, r:0x14},
            {l:0x20, r:0x20}
        ]};

    // 8bit classes
    static if ( is(char_t == char) )
    {
        static const CharClass!(char_t)
            any_char = {parts: [
                {l:0x00, r:0x00},
                {l:0x09, r:0x13},   // basic control chars
                {l:0x20, r:0x7e},   // basic latin
                {l:0xa0, r:0xff}    // latin-1 supplement
            ]},
            dot_oper = {parts: [
                {l:0x09, r:0x13},   // basic control chars
                {l:0x20, r:0x7e},   // basic latin
                {l:0xa0, r:0xff}    // latin-1 supplement
            ]},
            alphanum_ = {parts: [
                {l:0x30, r:0x39},
                {l:0x41, r:0x5a},
                {l:0x5f, r:0x5f},
                {l:0x61, r:0x7a}
            ]};
    }
    // 16bit and 32bit classes
    static if ( is(char_t == wchar) || is(char_t == dchar) )
    {
        static const CharClass!(char_t)
            any_char = {parts: [
                {l:0x00, r:0x00},
                {l:0x09,r:0x13},{l:0x20, r:0x7e},{l:0xa0, r:0xff},
                {l:0x0100, r:0x017f},   // latin extended a
                {l:0x0180, r:0x024f},   // latin extended b
                {l:0x20a3, r:0x20b5},   // currency symbols
            ]},
            dot_oper = {parts: [
                {l:0x09,r:0x13},{l:0x20, r:0x7e},{l:0xa0, r:0xff},
                {l:0x0100, r:0x017f},   // latin extended a
                {l:0x0180, r:0x024f},   // latin extended b
                {l:0x20a3, r:0x20b5},   // currency symbols
            ]},
            alphanum_ = {parts: [
                {l:0x30, r:0x39},
                {l:0x41, r:0x5a},
                {l:0x5f, r:0x5f},
                {l:0x61, r:0x7a}
            ]};
    }

    //---------------------------------------------------------------------------------------------
    range_t[] parts;

    int opCmp(CharClass cc)
    {
        if ( parts.length < cc.parts.length )
            return -1;
        if ( parts.length > cc.parts.length )
            return 1;
        foreach ( i, p; cc.parts )
        {
            if ( p.l != parts[i].l || p.r != parts[i].r )
                return 1;
        }
        return 0;
    }

    bool empty()
    {
        return parts.length <= 0;
    }

    bool matches(char_t c)
    {
        foreach ( p; parts )
        {
            if ( p.contains(c) )
                return true;
        }
        return false;
    }

    CharClass intersect(CharClass cc)
    {
        CharClass ic;
        foreach ( p; parts )
        {
            foreach ( cp; cc.parts )
            {
                if ( p.intersects(cp) )
                    ic.parts ~= p.intersect(cp);
            }
        }
        ic.optimize;
        return ic;
    }

    void subtract(CharClass cc)
    {
        negate;
        add(cc);
        negate;
        optimize;
    }

    void add(CharClass cc)
    {
        parts ~= cc.parts;
        optimize;
    }

    void add(char_t c)
    {
        parts ~= CharRange!(char_t)(c);
        optimize;
    }

    void negate()
    {
        if ( empty ) {
            parts ~= any_char.parts;
            return;
        }

        optimize;
        range_t[] oldparts = parts;
        parts = null;

        Stack!(range_t) stack;
        foreach_reverse ( p; any_char.parts )
            stack ~= p;
        outerLoop: while ( !stack.empty )
        {
            range_t r = stack.top;
            stack.pop;

            foreach ( op; oldparts )
            {
                range_t[] sr = r.subtract(op);

                if ( sr.length == 0 )
                    continue outerLoop;
                if ( sr.length == 2 )
                    stack ~= sr[1];
                r = sr[0];
            }
            
            parts ~= r;
        }
    }

    void optimize()
    {
        if ( empty )
            return;

        range_t[] oldparts = parts;
        oldparts.sort;
        parts = null;

        range_t cp = oldparts[0];
        foreach ( ocp; oldparts[1..$] )
        {
            if ( ocp.l > cp.r+1 ) {
                parts ~= cp;
                cp = ocp;
            }
            else if ( ocp.l <= cp.r+1 )
                cp.r = max(ocp.r, cp.r);
        }
        parts ~= cp;
    }

    char[] toString()
    {
        char[] str;
        str ~= "[";
        foreach ( p; parts )
            str ~= p.toString;
        str ~= "]";
        return str;
    }
}


/**************************************************************************************************

**************************************************************************************************/
private struct Predicate(char_t)
{
    alias char_t[]              string_t;
    alias CharClass!(char_t)    cc_t;
    alias CharRange!(char_t)    cr_t;

    enum Type {
        consume, epsilon, lookahead, lookbehind
    }

    private cc_t    input;
    Type            type;

    bool matches(char_t c)
    {
        if ( type == Type.consume || type == Type.lookahead )
            return input.matches(c);
        assert(0);
    }

    Predicate intersect(Predicate p)
    {
        Predicate p2;
        if ( type != Type.epsilon && p.type != Type.epsilon )
            p2.input = input.intersect(p.input);
        return p2;
    }

    bool empty()
    {
        return type != Type.epsilon && input.empty;
    }

    void subtract(Predicate p)
    {
        if ( type != Type.epsilon && p.type != Type.epsilon )
            input.subtract(p.input);
    }

    void negate()
    {
        assert(type != Type.epsilon);
        input.negate;
    }

    void optimize()
    {
        assert(type != Type.epsilon);
        input.optimize;
    }

    int opCmp(Predicate p)
    {
        return input.opCmp(p.input);
    }

    int opEquals(Predicate p)
    {
        if ( type != p.type )
            return 0;
        if ( input.opCmp(p.input) != 0 )
            return 0;
        return 1;
    }

    cc_t getInput()
    {
        return input;
    }

    void setInput(cc_t cc)
    {
        input = cc;
    }

    void appendInput(cr_t cr)
    {
        input.parts ~= cr;
    }

    string toString()
    {
        string str;
        switch ( type )
        {
            case Type.consume:      str = input.toString;       break;
            case Type.epsilon:      str = "eps";                break;
            case Type.lookahead:    str = "la:"~input.toString; break;
            case Type.lookbehind:   str = "lb:"~input.toString; break;
            default:
                assert(0);
        }
        return str;
    }
}
import Utf = tango.text.convert.Utf;
import tango.text.convert.Layout;

/**************************************************************************************************

**************************************************************************************************/
class RegExpException : Exception
{
    this(string msg)
    {
        super("RegExp: "~msg);
    }
}

/**************************************************************************************************
    TNFA state
**************************************************************************************************/
private class TNFAState(char_t)
{
    bool    accept = false,
            visited = false;
    uint    index;
    List!(TNFATransition!(char_t))  transitions;

    this()
    {
        transitions = new List!(TNFATransition!(char_t));
    }
}


/**************************************************************************************************
    Priority classes used to linearize priorities after non-linear transition creation.
**************************************************************************************************/
private enum PriorityClass {
    greedy=0, normal, reluctant, extraReluctant
}

/**************************************************************************************************
    TNFA tagged transition
**************************************************************************************************/
private class TNFATransition(char_t)
{
    TNFAState!(char_t)  target;
    Predicate!(char_t)  predicate;
    uint                priority,
                        tag;        /// one-based tag number, 0 = untagged
    PriorityClass       priorityClass;

    this(PriorityClass pc)
    {
        priorityClass = pc;
    }
}

/**************************************************************************************************
    Fragments of TNFAs as used in the Thompson method
**************************************************************************************************/
private class TNFAFragment(char_t)
{
    alias TNFAState!(char_t)        state_t;
    alias TNFATransition!(char_t)   trans_t;

    List!(trans_t)  entries,        /// transitions to be added to the entry state
                    exits,          /// transitions to be added to the exit state
                    entry_state,    /// transitions to write the entry state to
                    exit_state;     /// transitions to write the exit state to

    bool swapMatchingBracketSyntax;

    this()
    {
        entries     = new List!(trans_t);
        exits       = new List!(trans_t);
        entry_state = new List!(trans_t);
        exit_state  = new List!(trans_t);
    }

    /**********************************************************************************************
        Write the given state as entry state to this fragment.
    **********************************************************************************************/
    void setEntry(state_t state)
    {
        state.transitions ~= entries;
        foreach ( t; entry_state )
            t.target = state;
    }

    /**********************************************************************************************
        Write the given state as exit state to this fragment.
    **********************************************************************************************/
    void setExit(state_t state)
    {
        state.transitions ~= exits;
        foreach ( t; exit_state )
            t.target = state;
    }
}

/**************************************************************************************************
    Tagged NFA
**************************************************************************************************/
private class TNFA(char_t)
{
    alias TNFATransition!(char_t)   trans_t;
    alias TNFAFragment!(char_t)     frag_t;
    alias TNFAState!(char_t)        state_t;
    alias Predicate!(char_t)        predicate_t;
    alias char_t[]                  string_t;

    string_t    pattern;
    state_t[]   states;
    state_t     start;

    bool swapMatchingBracketSyntax; /// whether to make (?...) matching and (...) non-matching

    /**********************************************************************************************
        Creates the TNFA from the given regex pattern
    **********************************************************************************************/
    this(string_t regex)
    {
        next_tag        = 1;
        transitions     = new List!(trans_t);

        pattern = regex;
    }

    /**********************************************************************************************
        Print the TNFA (tabular representation of the delta function)
    **********************************************************************************************/
    void print()
    {
        foreach ( int i, s; states )
        {
            Stdout.format("{}{:d2}{}", s is start?">":" ", i, s.accept?"*":" ");

            bool first=true;
            Stdout(" {");
            foreach ( t; s.transitions )
            {
                Stdout.format("{}{}{}:{}->{}", first?"":", ", t.priority, "gnrx"[t.priorityClass], t.predicate.toString, t.target.index);
                if ( t.tag > 0 ) {
                    Stdout.format(" t{}", t.tag);
                }
                first = false;
            }
            Stdout("}").newline;
        }
    }

    uint tagCount()
    {
        return next_tag-1;
    }

    /**********************************************************************************************
        Constructs the TNFA using extended Thompson method.
        Uses a slightly extended version of Dijkstra's shunting yard algorithm to convert
        the regexp from infix notation.
    **********************************************************************************************/
    void parse(bool unanchored)
    {
        auto                layout = new Layout!(char);
        List!(frag_t)       frags       = new List!(frag_t);
        Stack!(Operator)    opStack;
        Stack!(uint)        tagStack;
        Stack!(Pair!(uint)) occurStack;
        opStack ~= Operator.eos;

        /******************************************************************************************
            Perform action on operator stack
        ******************************************************************************************/
        bool perform(Operator next_op, bool explicit_operator=true)
        {
            // calculate index in action matrix
            int index = cast(int)opStack.top*(Operator.max+1);
            index += cast(int)next_op;

            debug(tnfa) writefln("\t{}:{} -> {}  {} frag(s)",
                operator_names[opStack.top], operator_names[next_op], action_names[action_lookup[index]], frags.length
            );
            switch ( action_lookup[index] )
            {
                case Act.pua:
                    opStack ~= next_op;
                    if ( next_op == Operator.open_par ) {
                        tagStack ~= next_tag;
                        next_tag += 2;
                    }
                    break;
                case Act.poc:
                    switch ( opStack.top )
                    {
                        case Operator.concat:       constructConcat(frags);                             break;
                        case Operator.altern:       constructAltern(frags);                             break;
                        case Operator.zero_one_g:   constructZeroOne(frags, PriorityClass.greedy);      break;
                        case Operator.zero_one_ng:  constructZeroOne(frags, PriorityClass.reluctant);   break;
                        case Operator.zero_one_xr:  constructZeroOne(frags, PriorityClass.extraReluctant);  break;
                        case Operator.zero_more_g:  constructZeroMore(frags, PriorityClass.greedy);     break;
                        case Operator.zero_more_ng: constructZeroMore(frags, PriorityClass.reluctant);  break;
                        case Operator.zero_more_xr: constructZeroMore(frags, PriorityClass.extraReluctant); break;
                        case Operator.one_more_g:   constructOneMore(frags, PriorityClass.greedy);      break;
                        case Operator.one_more_ng:  constructOneMore(frags, PriorityClass.reluctant);   break;
                        case Operator.one_more_xr:  constructOneMore(frags, PriorityClass.extraReluctant);  break;
                        case Operator.occur_g:
                            Pair!(uint) occur = occurStack.pop;
                            constructOccur(frags, occur.a, occur.b, PriorityClass.greedy);
                            break;
                        case Operator.occur_ng:
                            Pair!(uint) occur = occurStack.pop;
                            constructOccur(frags, occur.a, occur.b, PriorityClass.reluctant);
                            break;
                        default:
                            throw new RegExpException("cannot process operand at \""~Utf.toString(pattern[cursor..$])~"\"");
                    }
                    opStack.pop;

                    perform(next_op, false);
                    break;
                case Act.poa:
                    opStack.pop;
                    break;
                case Act.pca:
                    if ( opStack.top == Operator.open_par )
                    {
                        if ( tagStack.empty )
                            throw new RegExpException(layout.convert("Missing opening parentheses for closing parentheses at char {} \"{}\"", cursor, Utf.toString(pattern[cursor..$])));
                        constructBracket(frags, tagStack.top);
                        tagStack.pop;
                    }
                    else {
                        assert(opStack.top == Operator.open_par_nm);
                        constructBracket(frags);
                    }
                    opStack.pop;
                    break;
                case Act.don:
                    return true;
                case Act.err:
                default:
                    throw new RegExpException(layout.convert("Unexpected operand at char {} \"{}\" in \"{}\"", cursor, Utf.toString(pattern[cursor..$]), Utf.toString(pattern)));
            }

            return false;
        }

        // add implicit extra reluctant .* at the beginning for unanchored matches
        // and matching bracket for total match group
        if ( unanchored ) {
            frags ~= constructChars(CharClass!(char_t).dot_oper, predicate_t.Type.consume);
            perform(Operator.zero_more_xr, false);
            perform(Operator.concat, false);
            perform(Operator.open_par, false);
        }

        // convert regex to postfix and create TNFA
        bool implicit_concat;
        predicate_t.Type pred_type;

        while ( !endOfPattern )
        {
            pred_type = predicate_t.Type.consume;

            dchar c = readPattern;
            switch ( c )
            {
                case '|':
                    perform(Operator.altern);
                    implicit_concat = false;
                    break;
                case '(':
                    if ( implicit_concat )
                        perform(Operator.concat, false);
                    implicit_concat = false;
                    if ( peekPattern == '?' ) {
                        readPattern;
                        perform(swapMatchingBracketSyntax?Operator.open_par:Operator.open_par_nm);
                    }
                    else
                        perform(swapMatchingBracketSyntax?Operator.open_par_nm:Operator.open_par);
                    break;
                case ')':
                    perform(Operator.close_par);
                    break;
                case '?':
                    if ( peekPattern == '?' ) {
                        readPattern;
                        perform(Operator.zero_one_ng);
                    }
                    else
                        perform(Operator.zero_one_g);
                    break;
                case '*':
                    if ( peekPattern == '?' ) {
                        readPattern;
                        perform(Operator.zero_more_ng);
                    }
                    else
                        perform(Operator.zero_more_g);
                    break;
                case '+':
                    if ( peekPattern == '?' ) {
                        readPattern;
                        perform(Operator.one_more_ng);
                    }
                    else
                        perform(Operator.one_more_g);
                    break;
                case '{':
                    Pair!(uint) occur;
                    parseOccurCount(occur.a, occur.b);
                    occurStack ~= occur;
                    if ( peekPattern == '?' ) {
                        readPattern;
                        perform(Operator.occur_ng);
                    }
                    else
                        perform(Operator.occur_g);
                    break;
                case '[':
                    if ( implicit_concat )
                        perform(Operator.concat, false);
                    implicit_concat = true;
                    frags ~= constructCharClass(pred_type);
                    break;
                case '.':
                    if ( implicit_concat )
                        perform(Operator.concat, false);
                    implicit_concat = true;
                    frags ~= constructChars(CharClass!(char_t).dot_oper, pred_type);
                    break;
                case '$':
                    if ( implicit_concat )
                        perform(Operator.concat, false);
                    implicit_concat = true;

                    frags ~= constructChars(CharClass!(char_t).line_startend, predicate_t.Type.lookahead);
                    break;
                case '^':
                    if ( implicit_concat )
                        perform(Operator.concat, false);
                    implicit_concat = true;

                    frags ~= constructChars(CharClass!(char_t).line_startend, predicate_t.Type.lookbehind);
                    break;
                case '>':
                    c = readPattern;
                    pred_type = predicate_t.Type.lookahead;
                    if ( c == '[' )
                        goto case '[';
                    else if ( c == '\\' )
                        goto case '\\';
                    else if ( c == '.' )
                        goto case '.';
                    else
                        goto default;
                    break;
                case '<':
                    c = readPattern;
                    pred_type = predicate_t.Type.lookbehind;
                    if ( c == '[' )
                        goto case '[';
                    else if ( c == '\\' )
                        goto case '\\';
                    else if ( c == '.' )
                        goto case '.';
                    else
                        goto default;
                    break;
                case '\\':
                    c = readPattern;

                    if ( implicit_concat )
                        perform(Operator.concat, false);
                    implicit_concat = true;

                    switch ( c )
                    {
                        case 't':
                            frags ~= constructSingleChar('\t', pred_type);
                            break;
                        case 'n':
                            frags ~= constructSingleChar('\n', pred_type);
                            break;
                        case 'r':
                            frags ~= constructSingleChar('\r', pred_type);
                            break;
                        case 'w':   // alphanumeric and _
                            frags ~= constructChars(CharClass!(char_t).alphanum_, pred_type);
                            break;
                        case 'W':   // non-(alphanum and _)
                            auto cc = CharClass!(char_t).alphanum_;
                            cc.negate;
                            frags ~= constructChars(cc, pred_type);
                            break;
                        case 's':   // whitespace
                            frags ~= constructChars(CharClass!(char_t).whitespace, pred_type);
                            break;
                        case 'S':   // non-whitespace
                            auto cc = CharClass!(char_t).whitespace;
                            cc.negate;
                            frags ~= constructChars(cc, pred_type);
                            break;
                        case 'd':   // digit
                            frags ~= constructChars(CharClass!(char_t).digit, pred_type);
                            break;
                        case 'D':   // non-digit
                            auto cc = CharClass!(char_t).digit;
                            cc.negate;
                            frags ~= constructChars(cc, pred_type);
                            break;
                        case 'b':   // either end of word
                            if ( pred_type != predicate_t.Type.consume )
                                throw new RegExpException("Escape sequence \\b not allowed in look-ahead or -behind");

                            // create (?<\S>\s|<\s>\S)
                            auto cc = CharClass!(char_t).whitespace;
                            cc.negate;

                            perform(Operator.open_par_nm);

                            frags ~= constructChars(cc, predicate_t.Type.lookbehind);
                            perform(Operator.concat, false);
                            frags ~= constructChars(CharClass!(char_t).whitespace, predicate_t.Type.lookahead);
                            perform(Operator.altern, false);
                            frags ~= constructChars(CharClass!(char_t).whitespace, predicate_t.Type.lookbehind);
                            perform(Operator.concat, false);
                            frags ~= constructChars(cc, predicate_t.Type.lookahead);
                            
                            perform(Operator.close_par, false);
                            break;
                        case 'B':   // neither end of word
                            if ( pred_type != predicate_t.Type.consume )
                                throw new RegExpException("Escape sequence \\B not allowed in look-ahead or -behind");

                            // create (?<\S>\S|<\s>\s)
                            auto cc = CharClass!(char_t).whitespace;
                            cc.negate;

                            perform(Operator.open_par_nm);

                            frags ~= constructChars(cc, predicate_t.Type.lookbehind);
                            perform(Operator.concat, false);
                            frags ~= constructChars(cc, predicate_t.Type.lookahead);
                            perform(Operator.altern, false);
                            frags ~= constructChars(CharClass!(char_t).whitespace, predicate_t.Type.lookbehind);
                            perform(Operator.concat, false);
                            frags ~= constructChars(CharClass!(char_t).whitespace, predicate_t.Type.lookahead);
                            
                            perform(Operator.close_par, false);
                            break;
                        case '(':
                        case ')':
                        case '[':
                        case ']':
                        case '{':
                        case '}':
                        case '*':
                        case '+':
                        case '?':
                        case '.':
                        case '\\':
                        case '^':
                        case '$':
                        case '|':
                        case '<':
                        case '>':
                            frags ~= constructSingleChar(c, pred_type);
                            break;
                        default:
                            throw new RegExpException(layout.convert("Unknown escape sequence \\{}", c));
                    }
                    break;

                default:
                    if ( implicit_concat )
                        perform(Operator.concat, false);
                    implicit_concat = true;
                    frags ~= constructSingleChar(c, pred_type);
            }
        }

        // add implicit reluctant .* at the end for unanchored matches
        if ( unanchored )
        {
            perform(Operator.close_par, false);
            if ( implicit_concat )
                perform(Operator.concat, false);
            frags ~= constructChars(CharClass!(char_t).dot_oper, predicate_t.Type.consume);
            perform(Operator.zero_more_ng, false);
        }

        // empty operator stack
        while ( !perform(Operator.eos) ) {}
        
        // set start and finish states
        start = addState;
        state_t finish = addState;
        finish.accept = true;

        foreach ( f; frags ) {
            f.setExit(finish);
            f.setEntry(start);
        }

        // set transition priorities
        List!(trans_t)[PriorityClass.max+1] trans;
        foreach ( inout t; trans )
            t = new List!(trans_t);

        Stack!(trans_t) todo;
        state_t state = start;

        while ( !todo.empty || !state.visited )
        {
            if ( !state.visited )
            {
                state.visited = true;
                foreach_reverse ( t; state.transitions )
                    todo ~= t;
            }

            if ( todo.empty )
                break;
            trans_t t = todo.top;
            todo.pop;
            assert(t.priorityClass<=PriorityClass.max);
            trans[t.priorityClass] ~= t;
            state = t.target;
        }

        uint nextPrio;
        foreach ( ts; trans )
        {
            foreach ( t; ts )
                t.priority = nextPrio++;
        }
    }

private:
    size_t          next_tag,
                    cursor,
                    next_cursor;
    List!(trans_t)  transitions;

    state_t[state_t]    clonedStates;
    trans_t[trans_t]    clonedTransitions;

    /// RegEx operators
    enum Operator {
        eos, concat, altern, open_par, close_par,
        zero_one_g, zero_more_g, one_more_g,        // greedy
        zero_one_ng, zero_more_ng, one_more_ng,     // non-greedy/reluctant
        zero_one_xr, zero_more_xr, one_more_xr,     // extra-reluctant
        open_par_nm, occur_g, occur_ng
    }
    const char[][] operator_names = ["EOS", "concat", "|", "(", ")", "?", "*", "+", "??", "*?", "+?", "??x", "*?x", "+?x", "(?", "{x,y}", "{x,y}?"];

    /// Actions for to-postfix transformation
    enum Act {
        pua, poc, poa, pca, don, err
    }
    const char[][] action_names = ["push+advance", "pop+copy", "pop+advance", "pop+copy+advance", "done", "error"];

    /// Action lookup for to-postfix transformation
    const Act[] action_lookup =
    [
    //  eos      concat   |        (        )        ?        *        +        ??       *?       +?       ??extra  *?extra  +?extra  (?       {x,y}    {x,y}?
        Act.don, Act.pua, Act.pua, Act.pua, Act.err, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua,
        Act.poc, Act.poc, Act.poc, Act.pua, Act.poc, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua,
        Act.poc, Act.pua, Act.poc, Act.pua, Act.poc, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua,
        Act.err, Act.pua, Act.pua, Act.pua, Act.pca, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua,
        Act.err, Act.err, Act.err, Act.err, Act.err, Act.err, Act.err, Act.err, Act.err, Act.err, Act.err, Act.err, Act.err, Act.err, Act.err, Act.err, Act.err,
        Act.poc, Act.poc, Act.poc, Act.pua, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.pua, Act.poc, Act.poc,
        Act.poc, Act.poc, Act.poc, Act.pua, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.pua, Act.poc, Act.poc,
        Act.poc, Act.poc, Act.poc, Act.pua, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.pua, Act.poc, Act.poc,
        Act.poc, Act.poc, Act.poc, Act.pua, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.pua, Act.poc, Act.poc,
        Act.poc, Act.poc, Act.poc, Act.pua, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.pua, Act.poc, Act.poc,
        Act.poc, Act.poc, Act.poc, Act.pua, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.pua, Act.poc, Act.poc,
        Act.poc, Act.poc, Act.poc, Act.pua, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.pua, Act.poc, Act.poc,
        Act.poc, Act.poc, Act.poc, Act.pua, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.pua, Act.poc, Act.poc,
        Act.poc, Act.poc, Act.poc, Act.pua, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.pua, Act.poc, Act.poc,
        Act.err, Act.pua, Act.pua, Act.pua, Act.pca, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua, Act.pua,
        Act.poc, Act.poc, Act.poc, Act.pua, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.pua, Act.poc, Act.poc,
        Act.poc, Act.poc, Act.poc, Act.pua, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.poc, Act.pua, Act.poc, Act.poc
    ];

    final dchar peekPattern()
    {
        auto tmp = next_cursor;
        if ( tmp < pattern.length )
            return decode(pattern, tmp);
        return 0;
    }

    final dchar readPattern()
    {
        cursor = next_cursor;
        if ( next_cursor < pattern.length )
            return decode(pattern, next_cursor);
        return 0;
    }

    final bool endOfPattern()
    {
        return next_cursor >= pattern.length;
    }

    state_t addState()
    {
        state_t s = new state_t;
        s.index = states.length;
        states ~= s;
        return s;
    }

    trans_t addTransition(PriorityClass pc = PriorityClass.normal)
    {
        trans_t trans = new trans_t(pc);
        transitions ~= trans;
        return trans;
    }

    uint parseNumber()
    {
        uint res;
        while ( !endOfPattern )
        {
            auto c = peekPattern;
            if ( c < '0' || c > '9' )
                break;
            res = res*10+(c-'0');
            readPattern;
        }
        return res;
    }

    void parseOccurCount(out uint minOccur, out uint maxOccur)
    {
        assert(pattern[cursor] == '{');

        minOccur = parseNumber;
        if ( peekPattern == '}' ) {
            readPattern;
            maxOccur = minOccur;
            return true;
        }
        if ( peekPattern != ',' )
            throw new RegExpException("Invalid occurence range at \""~Utf.toString(pattern[cursor..$])~"\"");
        readPattern;
        maxOccur = parseNumber;
        if ( peekPattern != '}' )
            throw new RegExpException("Invalid occurence range at \""~Utf.toString(pattern[cursor..$])~"\"");
        readPattern;
        if ( maxOccur > 0 && maxOccur < minOccur )
            throw new RegExpException("Invalid occurence range (max < min) at \""~Utf.toString(pattern[cursor..$])~"\"");
    }

    trans_t clone(trans_t t)
    {
        if ( t is null )
            return null;
        trans_t* tmp = t in clonedTransitions;
        if ( tmp !is null )
            return *tmp;

        trans_t t2 = new trans_t(t.priorityClass);
        clonedTransitions[t] = t2;
        t2.tag = t.tag;
        t2.priority = t.priority;
        t2.predicate = t.predicate;
        t2.target = clone(t.target);
        transitions ~= t2;
        return t2;
    }

    state_t clone(state_t s)
    {
        if ( s is null )
            return null;
        state_t* tmp = s in clonedStates;
        if ( tmp !is null )
            return *tmp;

        state_t s2 = new state_t;
        clonedStates[s] = s2;
        s2.accept = s.accept;
        s2.visited = s.visited;
        foreach ( t; s.transitions )
            s2.transitions ~= clone(t);
        s2.index = states.length;
        states ~= s2;
        return s2;
    }

    frag_t clone(frag_t f)
    {
        if ( f is null )
            return null;
        clonedStates = null;
        clonedTransitions = null;

        frag_t f2 = new frag_t;
        foreach ( t; f.entries )
            f2.entries ~= clone(t);
        foreach ( t; f.exits )
            f2.exits ~= clone(t);
        foreach ( t; f.entry_state )
            f2.entry_state ~= clone(t);
        foreach ( t; f.exit_state )
            f2.exit_state ~= clone(t);
        return f2;
    }

    //---------------------------------------------------------------------------------------------
    // Thompson constructions of NFA fragments

    frag_t constructSingleChar(char_t c, predicate_t.Type type)
    {
        debug(tnfa) {
            writef("constructCharFrag ");
            writefln("{}", c);
        }

        trans_t trans = addTransition;
        trans.predicate.appendInput(CharRange!(char_t)(c));

        trans.predicate.type = type;

        frag_t frag = new frag_t;
        frag.exit_state ~= trans;
        frag.entries    ~= trans;
        return frag;
    }

    frag_t constructChars(string_t chars, predicate_t.Type type)
    {
        CharClass!(char_t) cc;
        for ( int i = 0; i < chars.length; ++i )
            cc.add(chars[i]);

        return constructChars(cc, type);
    }

    frag_t constructChars(CharClass!(char_t) charclass, predicate_t.Type type)
    {
        debug(tnfa) writef("constructChars");

        trans_t trans = addTransition;
        trans.predicate.type = type;

        trans.predicate.setInput(charclass);

        trans.predicate.optimize;
        debug(tnfa) writefln("-> {}", trans.predicate.toString);

        frag_t frag = new frag_t;
        frag.exit_state ~= trans;
        frag.entries    ~= trans;
        return frag;
    }

    frag_t constructCharClass(predicate_t.Type type)
    {
        debug(tnfa) writef("constructCharClass");
        auto oldCursor = cursor;

        trans_t trans = addTransition;

        bool negated=false;
        if ( peekPattern == '^' ) {
            readPattern;
            negated = true;
        }

        char_t last;
        for ( ; !endOfPattern && peekPattern != ']'; )
        {
            dchar c = readPattern;
            switch ( c )
            {
                case '-':
                    if ( last == char_t.init )
                        throw new RegExpException("unexpected - operator at \""~Utf.toString(pattern[cursor..$])~"\"");
                    if ( peekPattern == ']' || peekPattern == 0 )
                        throw new RegExpException("unexpected end of string after \""~Utf.toString(pattern)~"\"");
                    trans.predicate.appendInput(CharRange!(char_t)(last, c));
                    last = char_t.init;
                    break;
                case '\\':
                    c = readPattern;
                    switch ( c )
                    {
                        case 't':
                            c = '\t';
                            break;
                        case 'n':
                            c = '\n';
                            break;
                        case 'r':
                            c = '\r';
                            break;
                        default:
                            break;
                    }
                default:
                    if ( last != char_t.init )
                        trans.predicate.appendInput(CharRange!(char_t)(last));
                    last = c;
            }
        }
        readPattern;
        if ( last != char_t.init )
            trans.predicate.appendInput(CharRange!(char_t)(last));
        debug(tnfa) writefln(" {}", pattern[oldCursor..cursor]);

        if ( negated )
            trans.predicate.negate;
        else
            trans.predicate.optimize;
        debug(tnfa) writefln("-> {}", trans.predicate.toString);

        trans.predicate.type = type;

        frag_t frag = new frag_t;
        frag.exit_state ~= trans;
        frag.entries    ~= trans;
        return frag;
    }

    void constructBracket(List!(frag_t) frags, uint tag=0)
    {
        debug(tnfa) writefln("constructBracket");

        state_t entry = addState,
                exit = addState;
        frags.tail.value.setEntry(entry);
        frags.tail.value.setExit(exit);

        trans_t tag1 = addTransition,
                tag2 = addTransition;
        tag1.predicate.type = predicate_t.Type.epsilon;
        tag2.predicate.type = predicate_t.Type.epsilon;
        if ( tag > 0 )
        {
            // make sure the tag indeces for bracket x are always
            // x*2 for the opening bracket and x*2+1 for the closing bracket
            tag1.tag = tag++;
            tag2.tag = tag;
        }
        tag1.target = entry;
        exit.transitions ~= tag2;

        frag_t frag = new frag_t;
        frag.entries ~= tag1;
        frag.exit_state ~= tag2;
        frags.pop;
        frags ~= frag;
    }

    void constructOneMore(List!(frag_t) frags, PriorityClass prioClass)
    {
        debug(tnfa) writefln("constructOneMore");

        if ( frags.empty )
            throw new RegExpException("too few arguments for + at \""~Utf.toString(pattern[cursor..$])~"\"");

        trans_t repeat = addTransition(prioClass),
                cont = addTransition;
        repeat.predicate.type = predicate_t.Type.epsilon;
        cont.predicate.type = predicate_t.Type.epsilon;

        state_t s = addState;
        frags.tail.value.setExit(s);
        s.transitions ~= repeat;
        s.transitions ~= cont;

        frag_t frag = new frag_t;
        frag.entries ~= frags.tail.value.entries;
        frag.entry_state ~= frags.tail.value.entry_state;
        frag.entry_state ~= repeat;
        frag.exit_state ~= cont;
        frags.pop;
        frags ~= frag;
    }

    void constructZeroMore(List!(frag_t) frags, PriorityClass prioClass)
    {
        debug(tnfa) writefln("constructZeroMore");

        if ( frags.empty )
            throw new RegExpException("too few arguments for * at \""~Utf.toString(pattern[cursor..$])~"\"");

        trans_t enter = addTransition(prioClass),
                repeat = addTransition(prioClass),
                skip = addTransition;
        skip.predicate.type = predicate_t.Type.epsilon;
        repeat.predicate.type = predicate_t.Type.epsilon;
        enter.predicate.type = predicate_t.Type.epsilon;

        state_t entry = addState,
                exit = addState;
        frags.tail.value.setEntry(entry);
        frags.tail.value.setExit(exit);
        exit.transitions ~= repeat;
        enter.target = entry;

        frag_t frag = new frag_t;
        frag.entries ~= skip;
        frag.entries ~= enter;
        frag.exit_state ~= skip;
        frag.entry_state ~= repeat;
        frags.pop;
        frags ~= frag;
    }

    void constructZeroOne(List!(frag_t) frags, PriorityClass prioClass)
    {
        debug(tnfa) writefln("constructZeroOne");

        if ( frags.empty )
            throw new RegExpException("too few arguments for ? at \""~Utf.toString(pattern[cursor..$])~"\"");

        trans_t use = addTransition(prioClass),
                skip = addTransition;
        use.predicate.type = predicate_t.Type.epsilon;
        skip.predicate.type = predicate_t.Type.epsilon;

        state_t s = addState;
        frags.tail.value.setEntry(s);
        use.target = s;

        frag_t frag = new frag_t;
        frag.entries ~= use;
        frag.entries ~= skip;
        frag.exits ~= frags.tail.value.exits;
        frag.exit_state ~= frags.tail.value.exit_state;
        frag.exit_state ~= skip;
        frags.pop;
        frags ~= frag;
    }

    void constructOccur(List!(frag_t) frags, uint minOccur, uint maxOccur, PriorityClass prioClass)
    {
        debug(tnfa) writefln(format("constructOccur {},{}", minOccur, maxOccur));

        if ( frags.empty )
            throw new RegExpException("too few arguments for {x,y} at \""~Utf.toString(pattern[cursor..$])~"\"");

        state_t s;
        frag_t  total = new frag_t,
                prev;

        for ( int i = 0; i < minOccur; ++i )
        {
            frag_t f = clone(frags.tail.value);
            if ( prev !is null ) {
                s = addState;
                prev.setExit(s);
                f.setEntry(s);
            }
            else {
                total.entries = f.entries;
                total.entry_state = f.entry_state;
            }
            prev = f;
        }
        
        if ( maxOccur == 0 )
        {
            frag_t f = frags.tail.value;
            trans_t t = addTransition;
            t.predicate.type = predicate_t.Type.epsilon;
            f.entries ~= t;
            f.exit_state ~= t;

            t = addTransition;
            t.predicate.type = predicate_t.Type.epsilon;
            f.exits ~= t;
            f.entry_state ~= t;

            s = addState;
            f.setEntry(s);

            if ( prev !is null )
                prev.setExit(s);
            else {
                total.entries = f.entries;
                total.entry_state = f.entry_state;
            }

            prev = f;
        }
        
        for ( int i = minOccur; i < maxOccur; ++i )
        {
            frag_t f;
            if ( i < maxOccur-1 )
                f = clone(frags.tail.value);
            else
                f = frags.tail.value;
            trans_t t = addTransition;
            t.predicate.type = predicate_t.Type.epsilon;
            f.entries ~= t;
            f.exit_state ~= t;

            if ( prev !is null ) {
                s = addState;
                prev.setExit(s);
                f.setEntry(s);
            }
            else {
                total.entries = f.entries;
                total.entry_state = f.entry_state;
            }
            prev = f;
        }

        total.exits = prev.exits;
        total.exit_state = prev.exit_state;

        frags.pop;
        frags ~= total;
    }

    void constructAltern(List!(frag_t) frags)
    {
        debug(tnfa) writefln("constructAltern");

        if ( frags.empty || frags.head is frags.tail )
            throw new RegExpException("too few arguments for | at \""~Utf.toString(pattern[cursor..$])~"\"");

        frag_t  frag = new frag_t,
                f1 = frags.tail.value,
                f2 = frags.tail.prev.value;
        frag.entry_state ~= f2.entry_state;
        frag.entry_state ~= f1.entry_state;
        frag.exit_state ~= f2.exit_state;
        frag.exit_state ~= f1.exit_state;
        frag.entries ~= f2.entries;
        frag.entries ~= f1.entries;
        frag.exits ~= f2.exits;
        frag.exits ~= f1.exits;

        frags.pop;
        frags.pop;
        frags ~= frag;
    }

    void constructConcat(List!(frag_t) frags)
    {
        debug(tnfa) writefln("constructConcat");

        if ( frags.empty || frags.head is frags.tail )
            throw new RegExpException("too few operands for concatenation at \""~Utf.toString(pattern[cursor..$])~"\"");

        frag_t  f1 = frags.tail.value,
                f2 = frags.tail.prev.value;

        state_t state = addState;
        f2.setExit(state);
        f1.setEntry(state);

        frag_t frag = new frag_t;
        frag.entries ~= f2.entries;
        frag.exits ~= f1.exits;
        frag.entry_state ~= f2.entry_state;
        frag.exit_state ~= f1.exit_state;
        frags.pop;
        frags.pop;
        frags ~= frag;
    }
}

/**************************************************************************************************
    Tagged DFA
**************************************************************************************************/
private class TDFA(char_t)
{
    alias Predicate!(char_t)    predicate_t;
    alias char_t[]              string_t;

    const uint CURRENT_POSITION_REGISTER = ~0;

    /**********************************************************************************************
        Tag map assignment command
    **********************************************************************************************/
    struct Command
    {
        uint        dst,    /// register index to recieve data
                    src;    /// register index or CURRENT_POSITION_REGISTER for current position

        string toString()
        {
            auto layout = new Layout!(char);
            return layout.convert("{}<-{}", dst, src==CURRENT_POSITION_REGISTER?"p":layout.convert("{}", src));
        }

        /******************************************************************************************
            Order transitions by the order of their predicates.
        ******************************************************************************************/
        int opCmp(Command cmd)
        {
            if ( src == CURRENT_POSITION_REGISTER && cmd.src != CURRENT_POSITION_REGISTER )
                return 1;
            if ( src != CURRENT_POSITION_REGISTER && cmd.src == CURRENT_POSITION_REGISTER )
                return -1;
            if ( dst < cmd.dst )
                return -1;
            if ( dst == cmd.dst )
                return 0;
            return 1;
        }
    }

    struct TagIndex
    {
        uint    tag,
                index;
    }

    /**********************************************************************************************
        TDFA state
    **********************************************************************************************/
    class State
    {
        bool            accept = false;
        uint            index;
        Transition[]    transitions;
        Command[]       finishers;
    }

    /**********************************************************************************************
        TDFA transition
    **********************************************************************************************/
    class Transition
    {
        State       target;
        predicate_t predicate;
        Command[]   commands;

        /******************************************************************************************
            Order transitions by the order of their predicates.
        ******************************************************************************************/
        int opCmp(Object o)
        {
            Transition t = cast(Transition)o;
            assert(t !is null);
            return predicate.opCmp(t.predicate);
        }
    }


    State[]     states;
    State       start;
    Command[]   initializer;
    uint        num_tags;

    uint[TagIndex]  registers;
    uint            next_register;

    uint num_regs()
    {
        return next_register;
    }

    /**********************************************************************************************
        Constructs the TDFA from the given TNFA using extended power set method
    **********************************************************************************************/
    this(TNFA!(char_t) tnfa)
    {
        num_tags        = tnfa.tagCount;
        assert(num_tags%2 == 0);
        next_register   = num_tags;
        for ( int i = 1; i <= num_tags; ++i ) {
            TagIndex ti;
            ti.tag = i;
            registers[ti] = i-1;
        }

        // create epsilon closure of TNFA start state
        SubsetState subset_start    = new SubsetState;
        StateElement se             = new StateElement;
        se.nfa_state = tnfa.start;
        subset_start.elms ~= se;
        subset_start = epsilonClosure(subset_start, subset_start);

        // apply lookbehind closure for string/line start
        predicate_t pred;
        pred.setInput(CharClass!(char_t).line_startend);
        subset_start = lookbehindClosure(subset_start, pred);

        start = addState;
        subset_start.dfa_state = start;

        // generate initializer and finisher commands for TDFA start state
        generateInitializers(subset_start);
        generateFinishers(subset_start);

        // initialize stack for state traversal
        List!(SubsetState)  subset_states   = new List!(SubsetState),
                            unmarked        = new List!(SubsetState);
        subset_states   ~= subset_start;
        unmarked        ~= subset_start;
        debug(tdfa) {
            Stdout.formatln("\n{} = {}\n", subset_start.dfa_state.index, subset_start);
        }

        while ( !unmarked.empty )
        {
            SubsetState state = unmarked.tail.value;
            unmarked.pop;

            // create transitions for each class, creating new states when necessary
            foreach ( pred; disjointPredicates(state) )
            {
                // find NFA state we reach with pred
                SubsetState target = reach(state, pred);
                if ( target is null )
                {
                    debug(tdfa) {
                        Stdout.formatln("from {} with {} - lookbehind at beginning", state.dfa_state.index, pred);
                    }
                    throw new Exception("Lookbehind at beginning of expression");
                }
                debug(tdfa) {
                    Stdout.formatln("from {} with {} reach {}", state.dfa_state.index, pred, target);
                }
                target = epsilonClosure(target, state);
                target = lookbehindClosure(target, pred);

                Transition trans = new Transition;
                state.dfa_state.transitions ~= trans;
                trans.predicate = pred;

                // generate indeces for pos commands
                // delay creation of pos command until we have reorder-commands
                uint[uint] cmds = null;
                foreach ( e; target.elms )
                {
                    foreach ( tag, ref index; e.tags )
                    {
                        bool found=false;
                        foreach ( e2; state.elms )
                        {
                            int* i = tag in e2.tags;
                            if ( i !is null && *i == index ) {
                                found=true;
                                break;
                            }
                        }
                        if ( !found )
                        {
                            // if index is < 0 it is a temporary index
							// used only to distinguish the state from existing ones.
							// the previous index can be reused instead.
                            if ( index < 0 )
                                index = -index-1;
                            cmds[tag] = index;
                        }
                        else
                            assert(index>=0);
                    }
                }

                // check whether a state exists that is identical except for tag index reorder-commands
                bool exists=false;
                foreach ( equivTarget; subset_states )
                {
                    if ( reorderTagIndeces(target, equivTarget, state, trans) ) {
                        target = equivTarget;
                        exists = true;
                        break;
                    }
                }
                // else create new target state
                if ( !exists )
                {
                    State ts = addState;
                    target.dfa_state = ts;
                    subset_states   ~= target;
                    unmarked        ~= target;
                    debug(tdfa) {
                        Stdout.formatln("\n{} = {}\n", target.dfa_state.index, target);
                    }
                    generateFinishers(target);
                }

                // now generate pos commands, rewriting reorder-commands if existent
                foreach ( tag, index; cmds )
                {
                    // check whether reordering used this tag, if so, overwrite the command directly,
                    // for it's effect would be overwritten by a subsequent pos-command anyway
                    uint reg = registerFromTagIndex(tag, index);
                    bool found = false;
                    foreach ( ref cmd; trans.commands )
                    {
                        if ( cmd.src == reg ) {
                            found = true;
                            cmd.src = CURRENT_POSITION_REGISTER;
                            break;
                        }
                    }
                    if ( !found ) {
                        Command cmd;
                        cmd.dst = reg;
                        cmd.src = CURRENT_POSITION_REGISTER;
                        trans.commands ~= cmd;
                    }
                }

                trans.target = target.dfa_state;
                debug(tdfa) {
                    Stdout.formatln("=> from {} with {} reach {}", state.dfa_state.index, pred, target.dfa_state.index);
                }
            }
        }

        // renumber registers continuously
        uint[uint]  regNums;

        for ( next_register = 0; next_register < num_tags; ++next_register )
            regNums[next_register] = next_register;

        void renumberCommand(ref Command cmd)
        {
            if ( cmd.src != CURRENT_POSITION_REGISTER && (cmd.src in regNums) is null )
                regNums[cmd.src] = next_register++;
            if ( (cmd.dst in regNums) is null )
                regNums[cmd.dst] = next_register++;
            if ( cmd.src != CURRENT_POSITION_REGISTER )
                cmd.src = regNums[cmd.src];
            cmd.dst = regNums[cmd.dst];
        }

        foreach ( state; states )
        {
            foreach ( ref cmd; state.finishers )
                renumberCommand(cmd);
            // make sure pos-commands are executed after reorder-commands and
            // reorder-commands do not overwrite each other
            state.finishers.sort;

            foreach ( trans; state.transitions )
            {
                foreach ( ref cmd; trans.commands )
                    renumberCommand(cmd);
                trans.commands.sort;
            }
        }

        // TODO: add lookahead for string end somewhere
        // TODO: minimize DFA
        // TODO: mark dead-end states (not leaving a non-finishing susbet)
        // TODO: mark states that can leave the finishing subset of DFA states or use a greedy transition
        //       (execution may stop in that state)
    }

    /**********************************************************************************************
        Print the TDFA (tabular representation of the delta function)
    **********************************************************************************************/
    void print()
    {
        Stdout.formatln("#tags = {}", num_tags);
        
        auto tis = new TagIndex[registers.length];
        foreach ( k, v; registers )
            tis [v] = k;
        foreach ( r, ti; tis ) {
            Stdout.formatln("tag({},{}) in reg {}", ti.tag, ti.index, r);
        }
        Stdout.formatln("Initializer:");
        foreach ( cmd; initializer ) {
            Stdout.formatln("{}", cmd.toString);
        }
        Stdout.formatln("Delta function:");
        foreach ( int i, s; states )
        {
            Stdout.format("{}{:d2}{}", s is start?">":" ", i, s.accept?"*":" ");

            bool first=true;
            Stdout(" {");
            foreach ( t; s.transitions )
            {
                Stdout.format("{}{}->{} (", first?"":", ", t.predicate.toString, t.target.index);
                bool firstcmd=true;
                foreach ( cmd; t.commands )
                {
                    if ( firstcmd )
                        firstcmd = false;
                    else
                        Stdout(",");
                    Stdout.format("{}", cmd.toString);
                }
                Stdout(")");
                first = false;
            }
            Stdout("} (");

            bool firstcmd=true;
            foreach ( cmd; s.finishers )
            {
                if ( firstcmd )
                    firstcmd = false;
                else
                    Stdout(",");
                Stdout.format("{}", cmd.toString);
            }
            Stdout.formatln(")");
        }
    }

private:
    /**********************************************************************************************
        A (TNFA state, tags) pair element of a subset state.
    **********************************************************************************************/
    class StateElement
    {
        TNFAState!(char_t)  nfa_state;
        int[uint]           tags;
        uint                maxPriority,
                            lastPriority;

        bool prioGreater(StateElement se)
        {
            if ( maxPriority < se.maxPriority )
                return true;
            if ( maxPriority == se.maxPriority ) {
                assert(lastPriority != se.lastPriority);
                return lastPriority < se.lastPriority;
            }
            return false;
        }

        int opCmp(Object o)
        {
            StateElement se = cast(StateElement)o;
            assert(se !is null);
            if ( maxPriority < se.maxPriority )
                return 1;
            if ( maxPriority == se.maxPriority )
            {
                if ( lastPriority == se.lastPriority )
                    return 0;
                return lastPriority < se.lastPriority;
            }
            return -1;
        }
        
        string toString()
        {
            string str;
            auto layout = new Layout!(char);
            str = layout.convert("{} p{}.{} {{", nfa_state.index, maxPriority, lastPriority);
            bool first = true;
            foreach ( k, v; tags ) {
                str ~= layout.convert("{}m({},{})", first?"":",", k, v);
                first = false;
            }
            str ~= "}";
            return str;
        }
    }

    /**********************************************************************************************
        Represents a state in the NFA to DFA conversion.
        Contains the set of states (StateElements) the NFA might be in at the same time and the
        corresponding DFA state that we create.
    **********************************************************************************************/
    class SubsetState
    {
        StateElement[]  elms;
        State           dfa_state;

        this(StateElement[] elms=null)
        {
            this.elms = elms;
        }
        
        string toString()
        {
            string str = "[ ";
            bool first = true;
            foreach ( s; elms ) {
                if ( !first )
                    str ~= ", ";
                str ~= s.toString;
                first = false;
            }
            return str~" ]";
        }
    }

    /**********************************************************************************************
        Calculates the register index for a given tag map entry. The TDFA implementation uses
        registers to save potential tag positions, the index space gets linearized here.
    
        Params:     tag =   tag number
                    index = tag map index
        Returns:    index of the register to use for the tag map entry
    **********************************************************************************************/
    uint registerFromTagIndex(uint tag, uint index)
    {
        if ( index > 0 )
        {
            TagIndex ti;
            ti.tag = tag;
            ti.index = index;
            uint* i = ti in registers;
            if ( i !is null )
                return *i;
            return registers[ti] = next_register++;
        }
        else
            return tag-1;
    }

    /**********************************************************************************************
        Add new TDFA state to the automaton.
    **********************************************************************************************/
    State addState()
    {
        State s = new State;
        s.index = states.length;
        states ~= s;
        return s;
    }

    /**********************************************************************************************
        Creates disjoint predicates from all outgoing, potentially overlapping TNFA transitions.

        Params:     state = SubsetState to create the predicates from
        Returns:    List of disjoint predicates that can be used for a DFA state
    **********************************************************************************************/
    List!(predicate_t) disjointPredicates(SubsetState state)
    {
        auto    queue = new List!(predicate_t),
                disjoint = new List!(predicate_t);

        foreach ( elm; state.elms )
        {
            foreach ( t; elm.nfa_state.transitions )
            {
                // partitioning will consider lookbehind transitions,
                // st. lb-closure will not expand for transitions with a superset of the lb-predicate
                if ( t.predicate.type != predicate_t.Type.epsilon )
                    queue ~= t.predicate;
            }
        }

        while ( !queue.empty )
        {
            predicate_t pred = queue.head.value;
            queue.remove(queue.head);

            bool intersected=false;
            foreach ( inout pred2; &queue.elements )
            {
                auto intpred = pred.intersect(pred2.value);
                if ( !intpred.empty )
                {
                    intersected = true;
                    pred.subtract(intpred);
                    pred2.value.subtract(intpred);
                    if ( pred2.value.empty )
                        queue.remove(pred2);
                    // make sure we don't process intpred in this loop again
                    queue.pushFront(intpred);
                    if ( pred.empty )
                        break;
                }
            }
            if ( !pred.empty )
            {
                if ( intersected )
                    queue ~= pred;
                // lb-transitions are not added, since result is used for reach
                else if ( pred.type != predicate_t.Type.lookbehind )
                    disjoint ~= pred;
            }
        }

        return disjoint;
    }

    /**********************************************************************************************
        Finds all TNFA states that can be reached directly with the given predicate and creates
        a new SubsetState containing those target states.
    
        Params:     subst = SubsetState to start from
                    pred =  predicate that is matched against outgoing transitions
        Returns:    SubsetState containing the reached target states
    **********************************************************************************************/
    SubsetState reach(SubsetState subst, ref predicate_t pred)
    {
        // to handle the special case of overlapping consume and lookahead predicates,
        // we find the different intersecting predicate types
        bool    have_consume,
                have_lookahead;
        foreach ( s; subst.elms )
        {
            foreach ( t; s.nfa_state.transitions )
            {
                if ( t.predicate.type != predicate_t.Type.consume && t.predicate.type != predicate_t.Type.lookahead )
                    continue;
                auto intpred = t.predicate.intersect(pred);
                if ( !intpred.empty )
                {
                    if ( t.predicate.type == predicate_t.Type.consume )
                        have_consume = true;
                    else if ( t.predicate.type == predicate_t.Type.lookahead )
                        have_lookahead = true;
                    else
                        assert(0);
                }
            }
        }

        // if there is consume/lookahead overlap,
        // lookahead predicates are handled first
        predicate_t.Type processed_type;
        if ( have_lookahead )
            processed_type = predicate_t.Type.lookahead;
        else if ( have_consume )
            processed_type = predicate_t.Type.consume;
        else
            return null;
        pred.type = processed_type;

        // add destination states to new subsetstate
        SubsetState r = new SubsetState;
        foreach ( s; subst.elms )
        {
            foreach ( t; s.nfa_state.transitions )
            {
                if ( t.predicate.type != processed_type )
                    continue;
                auto intpred = t.predicate.intersect(pred);
                if ( !intpred.empty ) {
                    StateElement se = new StateElement;
                    se.maxPriority = max(t.priority, s.maxPriority);
                    se.lastPriority = t.priority;
                    se.nfa_state = t.target;
                    se.tags = s.tags;
                    r.elms ~= se;
                }
            }
        }

        // if we prioritized lookaheads, the states that may consume are also added to the new subset state
        // this behaviour is somewhat similar to an epsilon closure
        if ( have_lookahead && have_consume )
        {
            foreach ( s; subst.elms )
            {
                foreach ( t; s.nfa_state.transitions )
                {
                    if ( t.predicate.type != predicate_t.Type.consume )
                        continue;
                    auto intpred = t.predicate.intersect(pred);
                    if ( !intpred.empty ) {
                        r.elms ~= s;
                        break;
                    }
                }
            }
        }
        return r;
    }

    /**********************************************************************************************
        Extends the given SubsetState with the states that are reached through lookbehind transitions.
    
        Params:     from =      SubsetState to create the lookbehind closure for
                    previous =  predicate "from" was reached with
        Returns:    SubsetState containing "from" and all states of it's lookbehind closure
    **********************************************************************************************/
    SubsetState lookbehindClosure(SubsetState from, predicate_t pred)
    {
        List!(StateElement) stack = new List!(StateElement);
        StateElement[uint]  closure;

        foreach ( e; from.elms )
        {
            stack ~= e;
            closure[e.nfa_state.index] = e;
        }

        while ( !stack.empty )
        {
            StateElement se = stack.tail.value;
            stack.pop;
            foreach ( t; se.nfa_state.transitions )
            {
                if ( t.predicate.type != predicate_t.Type.lookbehind )
                    continue;
                if ( t.predicate.intersect(pred).empty )
                    continue;
                StateElement new_se = new StateElement;
                new_se.maxPriority = max(t.priority, se.maxPriority);
                new_se.lastPriority = t.priority;
                new_se.nfa_state = t.target;
                new_se.tags = se.tags;

                closure[t.target.index] = new_se;
                stack ~= new_se;
            }
        }

        SubsetState res = new SubsetState;
        res.elms = closure.values;
        return res;
    }

    /**********************************************************************************************
        Generates the epsilon closure of the given subset state, creating tag map entries
        if tags are passed. Takes priorities into account, effectively realizing
        greediness and reluctancy.
    
        Params:     from =      SubsetState to create the epsilon closure for
                    previous =  SubsetState "from" was reached from
        Returns:    SubsetState containing "from" and all states of it's epsilon closure
    **********************************************************************************************/
    SubsetState epsilonClosure(SubsetState from, SubsetState previous)
    {
        int firstFreeIndex=-1;
        foreach ( e; previous.elms )
        {
            foreach ( ti; e.tags )
                firstFreeIndex = max(firstFreeIndex, cast(int)ti);
        }
        ++firstFreeIndex;

        List!(StateElement) stack = new List!(StateElement);
        StateElement[uint]  closure;

        foreach ( e; from.elms )
        {
            stack ~= e;
            closure[e.nfa_state.index] = e;
        }

        while ( !stack.empty )
        {
            StateElement se = stack.tail.value;
            stack.pop;
            foreach ( t; se.nfa_state.transitions )
            {
                if ( t.predicate.type != predicate_t.Type.epsilon )
                    continue;
                // this is different from Ville Laurikari's algorithm, but it's crucial
                // to take the max (instead of t.priority) to make reluctant operators work
                uint new_maxPri = max(t.priority, se.maxPriority);

                StateElement* tmp = t.target.index in closure;
                if ( tmp !is null )
                {
                    // if smaller prio exists, do not use this transition
                    if ( tmp.maxPriority < new_maxPri ) {
                        debug(tdfa) writefln("maxPrio({}) {} beats {}", t.target.index, tmp.maxPriority, new_maxPri);
                        continue;
                    }
                    else if ( tmp.maxPriority == new_maxPri )
                    {
                        if ( tmp.lastPriority < t.priority ) {
                            debug(tdfa) writefln("lastPrio({}) {} beats {}", t.target.index, tmp.lastPriority, t.priority);
                            continue;
                        }
                        else
                            debug(tdfa) writefln("lastPrio({}) {} beats {}", t.target.index, t.priority, tmp.lastPriority);
                    }
                    else
                        debug(tdfa) writefln("maxPrio({}) {} beats {}", t.target.index, new_maxPri, tmp.maxPriority);
                }
                StateElement new_se = new StateElement;
                new_se.maxPriority = new_maxPri;
                new_se.lastPriority = t.priority;
                new_se.nfa_state = t.target;

                if ( t.tag > 0 )
                {
                    foreach ( k, v; se.tags )
                        new_se.tags[k] = v;
                    new_se.tags[t.tag] = firstFreeIndex;
                }
                else
                    new_se.tags = se.tags;

                closure[t.target.index] = new_se;
                stack ~= new_se;
            }
        }

        SubsetState res = new SubsetState;
        res.elms = closure.values;

        // optimize tag usage
        // all we need to do is to check whether the largest tag-index from the
        // previous state is actually used in the new state and move all tags with
        // firstFreeIndex down by one if not, but only if firstFreeIndex is not 0
        if ( firstFreeIndex > 0 )
        {
            bool seenLastUsedIndex = false;
            sluiLoop: foreach ( e; res.elms )
            {
                foreach ( i; e.tags )
                {
                    if ( i == firstFreeIndex-1 ) {
                        seenLastUsedIndex = true;
                        break sluiLoop;
                    }
                }
            }
            if ( !seenLastUsedIndex )
            {
                foreach ( e; res.elms )
                {
                    foreach ( inout i; e.tags )
                    {
                        // mark index by making it negative
                        // to signal that it can be decremented
                        // after it has been detected to be a newly used index
                        if ( i == firstFreeIndex )
                            i = -firstFreeIndex;
                    }
                }
            }
        }

        return res;
    }

    /**********************************************************************************************
        Tries to create commands that reorder the tag map of "previous", such that "from" becomes
        tag-wise identical to "to". If successful, these commands are added to "trans". This
        is done for state re-use.
    
        Params:     from =      SubsetState to check for tag-wise equality to "to"
                    to =        existing SubsetState that we want to re-use
                    previous =  SubsetState we're coming from
                    trans =     Transition we went along
        Returns:    true if "from" is tag-wise identical to "to" and the necessary commands have
                    been added to "trans"
    **********************************************************************************************/
    bool reorderTagIndeces(SubsetState from, SubsetState to, SubsetState previous, Transition trans)
    {
        if ( from.elms.length != to.elms.length )
            return false;

        bool[Command]   cmds;
        uint[TagIndex]  reorderedIndeces;

        foreach ( fe; from.elms )
        {
            bool foundState = false;
            foreach ( te; to.elms )
            {
                if ( te.nfa_state.index != fe.nfa_state.index )
                    continue;
                foundState = true;
                foreach ( tag, findex; fe.tags )
                {
                    if ( (tag in te.tags) is null )
                        return false;

                    TagIndex ti;
                    ti.tag = tag;
                    ti.index = te.tags[tag];

                    if ( (ti in reorderedIndeces) !is null )
                    {
                        if ( reorderedIndeces[ti] != findex )
                            return false;
                    }
                    else if ( te.tags[tag] != findex )
                    {
                        reorderedIndeces[ti] = findex;
                        Command cmd;
                        cmd.src = registerFromTagIndex(tag,findex);
                        cmd.dst = registerFromTagIndex(tag,te.tags[tag]);
                        cmds[cmd] = true;
                    }
                }
            }
            if ( !foundState )
                return false;
        }

        debug(tdfa) {
            Stdout.formatln("\nreorder {} to {}\n", from, to.dfa_state.index);
        }

        trans.commands ~= cmds.keys;
        return true;
    }

    /**********************************************************************************************
        Generate tag map initialization commands for start state.
    **********************************************************************************************/
    void generateInitializers(SubsetState start)
    {
        uint[uint] cmds;
        foreach ( nds; start.elms )
        {
            foreach ( k, v; nds.tags )
                cmds[k] = v;
        }

        foreach ( k, v; cmds ) {
            Command cmd;
            cmd.dst = registerFromTagIndex(k,v);
            cmd.src = CURRENT_POSITION_REGISTER;
            initializer ~= cmd;
        }
    }

    /**********************************************************************************************
        Generates finisher commands for accepting states.
    **********************************************************************************************/
    void generateFinishers(SubsetState r)
    {
        // if at least one of the TNFA states accepts,
        // set the finishers from active tags in increasing priority
        StateElement[]  sorted_elms = r.elms.dup.sort;
        foreach ( se; sorted_elms )
            if ( se.nfa_state.accept )
            {
                r.dfa_state.accept = true;
                bool[uint]  finished_tags;
                {
                    foreach ( t, i; se.tags )
                        if ( i > 0 && !(t in finished_tags) ) {
                            finished_tags[t] = true;
                            Command cmd;
                            cmd.dst = registerFromTagIndex(t, 0);
                            cmd.src = registerFromTagIndex(t, i);
                            r.dfa_state.finishers ~= cmd;
                        }
                }
            }
    }
}
/**************************************************************************************************
    Regular expression compiler and interpreter.

    In the following description, X stands for an arbitrary regular expression.

    Operators:
        |       alternation
        (X)     matching brackets - creates a sub-match
        (?X)    non-matching brackets - only groups X, no sub-match is created
        [X]     character class specification
        <X      lookbehind, X may be a single character or a character class
        >X      lookahead, X may be a single character or a character class 
        ^       start of input or start of line
        $       end of input or end of line
        \b      start or end of word, equals (?<\s>\S|<\S>\s)
        \B      opposite of \b, equals (?<\S>\S|<\s>\s)

    Quantifiers:
        X?      zero or one
        X*      zero or more
        X+      one or more
        X{n,m}  at least n, at most m instances of X
                If n is missing, it's set to 0. If m is missing, it is set to infinity.
        X??     non-greedy version of the above operators
        X*?
        X+?
        X{n,m}?

    Pre-defined character classes:
        .       any printable character
        \s      whitespace
        \S      non-whitespace
        \w      alpha-numeric characters or _
        \W      opposite of \w
        \d      digits
        \D      non-digit
**************************************************************************************************/
class RegExpT(char_t)
{
    alias char_t[]          string_t;
    alias TDFA!(dchar)      tdfa_t;
    alias TNFA!(dchar)      tnfa_t;
    alias CharClass!(dchar) charclass_t;

    static const char[] VERSION = "0.3 alpha";

    this(string_t pattern, bool swapMBS=false, bool unanchored=true)
    {
        static if ( is(char_t == dchar) ) {
            tnfa = new tnfa_t(pattern);
        }
        else {
            tnfa = new tnfa_t(tango.text.convert.Utf.toString32(pattern));
        }
        tnfa.swapMatchingBracketSyntax = swapMBS;
        tnfa.parse(unanchored);
        tdfa = new tdfa_t(tnfa);
        registers.length = tdfa.num_regs;
    }

    static RegExpT!(char_t) opCall(string_t pattern, bool swapMBS=false)
    {
        return new RegExpT!(char_t)(pattern, swapMBS);
    }

    /**********************************************************************************************
        Run TDFA on given input
    **********************************************************************************************/
    bool match(string_t input)
    {
        this.input = input;
        auto s = tdfa.start;

        // initialize registers
        assert(registers.length == tdfa.num_regs);
        registers[0..$] = -1;
        foreach ( cmd; tdfa.initializer ) {
            assert(cmd.src == tdfa.CURRENT_POSITION_REGISTER);
            registers[cmd.dst] = 0;
        }

        // DFA execution
        debug Stdout.formatln("{}{}: {}", s.accept?"*":" ", s.index, input[0..$]);
        dfaLoop: for ( size_t p, next_p; p < input.length; )
        {
            version(LexerTest)
            {
                if ( s.accept )
                {
                    if ( s.transitions.length == 0 )
                        break;
                    auto first_t = s.transitions[0].target;
                    if ( first_t is s )
                    {
                        foreach ( t; s.transitions[1 .. $] )
                        {
                            if ( t.target !is first_t )
                                goto noAccept;
                        }
                        break;
                        noAccept: {}
                    }
                }
            }

            next_p = p;
            dchar c = decode(input, next_p);
        processChar:
            debug {
                Stdout.formatln("{} (0x{:x})", c, cast(int)c);
            }

            foreach ( t; s.transitions )
            {
                if ( t.predicate.matches(c) )
                {
                    if ( t.predicate.type == typeof(t.predicate).Type.consume )
                        p = next_p;

                    foreach ( cmd; t.commands )
                    {
                        if ( cmd.src == tdfa.CURRENT_POSITION_REGISTER )
                            registers[cmd.dst] = p;
                        else
                            registers[cmd.dst] = registers[cmd.src];
                    }

                    s = t.target;
                    debug writefln("{}{}: {}", s.accept?"*":" ", s.index, input[p..$]);

                    // if input ends here and do not already accept, try to add an explicit string/line end
                    if ( p >= input.length && !s.accept && c != 0 ) {
                        c = 0;
                        goto processChar;
                    }
                    continue dfaLoop;
                }
            }
            break;
        }

        if ( s.accept )
        {
            foreach ( cmd; s.finishers )
            {
                assert(cmd.src != tdfa.CURRENT_POSITION_REGISTER);
                registers[cmd.dst] = registers[cmd.src];
            }
            return true;
        }

        return false;
    }

    /**********************************************************************************************
        Return submatch with the given index
        index = 0   = whole match
        index > 0   = submatch of bracket #index
    **********************************************************************************************/
    string_t submatch(uint index)
    {
        if ( index > tdfa.num_tags )
            return null;
        int start   = registers[index*2],
            end     = registers[index*2+1];
        if ( start >= 0 && start < end && end <= input.length )
            return input[start .. end];
        return null;
    }

    /**********************************************************************************************
        Compiles TDFA to D code
    **********************************************************************************************/
    // TODO: input-end special case
    string compileToD(string func_name = "match", bool lexer=false)
    {
        string code;
        string str_type;
        static if ( is(char_t == char) )
            str_type = "string";
        static if ( is(char_t == wchar) )
            str_type = "wstring";
        static if ( is(char_t == dchar) )
            str_type = "dstring";
        auto layout = new Layout!(char);

        if ( lexer )
            code = layout.convert("// %s\nbool %s(%s input, out uint token, out %s match", tnfa.pattern, func_name, str_type, str_type);
        else
        {
            code = layout.convert("// %s\nbool match(%s input", tnfa.pattern, str_type);
            for ( int i = 0; i < tdfa.num_tags/2; ++i )
                code ~= layout.convert(", out %s group%d", str_type, i);
        }
        code ~= layout.convert(")\n{\n    uint s = %d;", tdfa.start.index);

        uint num_vars = tdfa.num_regs;
        if ( num_vars > 0 )
        {
            if ( lexer )
                code ~= "\n    static int ";
            else
                code ~= "\n    int ";
            bool first = true;
            for ( int i = 0, used = 0; i < num_vars; ++i )
            {
                if ( lexer && i < tdfa.num_tags )
                    continue;

                bool hasInit = false;
                foreach ( cmd; tdfa.initializer )
                {
                    if ( cmd.dst == i ) {
                        hasInit = true;
                        break;
                    }
                }

                if ( first )
                    first = false;
                else
                    code ~= ", ";
                if ( used > 0 && used % 10 == 0 )
                    code ~= "\n        ";
                ++used;
                code ~= layout.convert("r%d", i);

                if ( hasInit )
                    code ~= "=0";
                else
                    code ~= "=-1";
            }
            code ~= ";";
        }

        code ~= "\n\n    for ( size_t p = 0, q = 0, p_end = input.length; p < p_end; q = p )\n    {";
        code ~= "\n        dchar c = cast(dchar)input[p];\n        if ( c & 0x80 )\n            decode(input, p);";
        code ~= "\n        else\n            ++p;\n        switch ( s )\n        {";

        uint[] finish_states;
        foreach ( s; tdfa.states )
        {
            code ~= layout.convert("\n            case %d:", s.index);

            if ( s.accept )
            {
                finish_states ~= s.index;

                tdfa_t.State target;
                foreach ( t; s.transitions )
                {
                    if ( target is null )
                        target = t.target;
                    else if ( target !is t.target )
                    {
                        target = null;
                        break;
                    }
                }
                if ( target !is null && target is s )
                    s.transitions = null;
            }

            bool first_if=true;
            charclass_t cc, ccTest;

            foreach ( t; s.transitions.sort )
            {
                ccTest.add(t.predicate.getInput);
                ccTest.optimize;
                if ( t.predicate.getInput < ccTest )
                    cc = t.predicate.getInput;
                else
                    cc = ccTest;

                if ( first_if ) {
                    code ~= "\n                if ( ";
                    first_if = false;
                }
                else
                    code ~= "\n                else if ( ";
                bool first_cond=true;
                foreach ( cr; cc.parts )
                {
                    if ( first_cond )
                        first_cond = false;
                    else
                        code ~= " || ";
                    if ( cr.l == cr.r )
                        code ~= layout.convert("c == 0x%x", cr.l);
                    else
                        code ~= layout.convert("c >= 0x%x && c <= 0x%x", cr.l, cr.r);
                }
                code ~= layout.convert(" ) {\n                    s = %d;", t.target.index);

                foreach ( cmd; t.commands )
                    code ~= compileCommand(layout, t.predicate.type == typeof(t.predicate.type).lookahead, cmd, "                    ");
                if ( t.predicate.type == typeof(t.predicate.type).lookahead )
                    code ~= "\n                    p = q;";
                code ~= "\n                }";
            }

            if ( !first_if )
                code ~= layout.convert(
                    "\n                else\n                    %s;\n                break;",
                    s.accept?layout.convert("goto finish%d", s.index):"return false"
                );
            else
                code ~= layout.convert("\n                %s;", s.accept?layout.convert("goto finish%d", s.index):"return false");
        }

        // create finisher groups
        uint[][uint] finisherGroup;
        foreach ( fs; finish_states )
        {
            // check if finisher group with same commands exists
            bool haveFinisher = false;
            foreach ( fg; finisherGroup.keys )
            {
                bool equalCommands = false;
                if ( tdfa.states[fs].finishers.length == tdfa.states[fg].finishers.length )
                {
                    equalCommands = true;
                    foreach ( i, cmd; tdfa.states[fs].finishers )
                    {
                        if ( cmd != tdfa.states[fg].finishers[i] ) {
                            equalCommands = false;
                            break;
                        }
                    }
                }
                if ( equalCommands ) {
                    // use existing group for this state
                    finisherGroup[fg] ~= fs;
                    haveFinisher = true;
                    break;
                }
            }
            // create new group
            if ( !haveFinisher )
                finisherGroup[fs] ~= fs;
        }


        code ~= "\n            default:\n                assert(0);\n        }\n    }\n\n    switch ( s )\n    {";
        foreach ( group, states; finisherGroup )
        {
            foreach ( s; states )
                code ~= layout.convert("\n        case %d: finish%d:", s, s);

            foreach ( cmd; tdfa.states[group].finishers )
            {
                if ( lexer )
                {
                    if ( tdfa.states[group].finishers.length > 1 )
                        throw new Exception("Lexer error: more than one finisher in flm lexer!");
                    if ( cmd.dst % 2 == 0 || cmd.dst >= tdfa.num_tags )
                        throw new Exception(layout.convert("Lexer error: unexpected dst register %d in flm lexer!", cmd.dst));
                    code ~= layout.convert("\n            match = input[0 .. r%d];\n            token = %d;", cmd.src, cmd.dst/2);
                }
                else
                    code ~= compileCommand(layout, false, cmd, "            ");
            }

            code ~= "\n            break;";
        }
        code ~= "\n        default:\n            return false;\n    }";

        if ( !lexer )
        {
            for ( int i = 0; i < tdfa.num_tags/2; ++i )
                code ~= layout.convert("\n    if ( r%d > -1 && r%d > -1 )\n        group%d = input[r%d .. r%d];", 2*i, 2*i+1, i, 2*i, 2*i+1);
        }

        code ~= "\n    return true;\n}";
        return code;
    }

    tnfa_t      tnfa;
    tdfa_t      tdfa;
    int[]       registers;
    string_t    input;

private:
    string compileCommand(Layout!(char) layout, bool is_lookahead, tdfa_t.Command cmd, string_t indent)
    {
        string  code,
                dst;
        code ~= layout.convert("\n%sr%d = ", indent, cmd.dst);
        if ( cmd.src != tdfa.CURRENT_POSITION_REGISTER )
            code ~= layout.convert("r%d;", cmd.src);
        else
        {
            if ( is_lookahead )
                code ~= layout.convert("q;");
            else
                code ~= layout.convert("p;");
        }
        return code;
    }
}

alias RegExpT!(char)     RegExp;
alias RegExpT!(wchar)    RegExpw;
alias RegExpT!(dchar)    RegExpd;
public import tango.io.Stdout;

alias char[] string;

// the following block is stolen from phobos.
// the copyright notice applies for this block only.
/*
 *  Copyright (C) 2003-2004 by Digital Mars, www.digitalmars.com
 *  Written by Walter Bright
 *
 *  This software is provided 'as-is', without any express or implied
 *  warranty. In no event will the authors be held liable for any damages
 *  arising from the use of this software.
 *
 *  Permission is granted to anyone to use this software for any purpose,
 *  including commercial applications, and to alter it and redistribute it
 *  freely, subject to the following restrictions:
 *
 *  o  The origin of this software must not be misrepresented; you must not
 *     claim that you wrote the original software. If you use this software
 *     in a product, an acknowledgment in the product documentation would be
 *     appreciated but is not required.
 *  o  Altered source versions must be plainly marked as such, and must not
 *     be misrepresented as being the original software.
 *  o  This notice may not be removed or altered from any source
 *     distribution.
 */

class UtfException : Exception
{
    size_t idx;	/// index in string of where error occurred

    this(char[] s, size_t i)
    {
	idx = i;
	super(s);
    }
}

bool isValidDchar(dchar c)
{
    /* Note: FFFE and FFFF are specifically permitted by the
     * Unicode standard for application internal use, but are not
     * allowed for interchange.
     * (thanks to Arcane Jill)
     */

    return c < 0xD800 ||
	(c > 0xDFFF && c <= 0x10FFFF /*&& c != 0xFFFE && c != 0xFFFF*/);
}

/***************
 * Decodes and returns character starting at s[idx]. idx is advanced past the
 * decoded character. If the character is not well formed, a UtfException is
 * thrown and idx remains unchanged.
 */

dchar decode(in char[] s, inout size_t idx)
    {
	size_t len = s.length;
	dchar V;
	size_t i = idx;
	char u = s[i];

	if (u & 0x80)
	{   uint n;
	    char u2;

	    /* The following encodings are valid, except for the 5 and 6 byte
	     * combinations:
	     *	0xxxxxxx
	     *	110xxxxx 10xxxxxx
	     *	1110xxxx 10xxxxxx 10xxxxxx
	     *	11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
	     *	111110xx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
	     *	1111110x 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
	     */
	    for (n = 1; ; n++)
	    {
		if (n > 4)
		    goto Lerr;		// only do the first 4 of 6 encodings
		if (((u << n) & 0x80) == 0)
		{
		    if (n == 1)
			goto Lerr;
		    break;
		}
	    }

	    // Pick off (7 - n) significant bits of B from first byte of octet
	    V = cast(dchar)(u & ((1 << (7 - n)) - 1));

	    if (i + (n - 1) >= len)
		goto Lerr;			// off end of string

	    /* The following combinations are overlong, and illegal:
	     *	1100000x (10xxxxxx)
	     *	11100000 100xxxxx (10xxxxxx)
	     *	11110000 1000xxxx (10xxxxxx 10xxxxxx)
	     *	11111000 10000xxx (10xxxxxx 10xxxxxx 10xxxxxx)
	     *	11111100 100000xx (10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx)
	     */
	    u2 = s[i + 1];
	    if ((u & 0xFE) == 0xC0 ||
		(u == 0xE0 && (u2 & 0xE0) == 0x80) ||
		(u == 0xF0 && (u2 & 0xF0) == 0x80) ||
		(u == 0xF8 && (u2 & 0xF8) == 0x80) ||
		(u == 0xFC && (u2 & 0xFC) == 0x80))
		goto Lerr;			// overlong combination

	    for (uint j = 1; j != n; j++)
	    {
		u = s[i + j];
		if ((u & 0xC0) != 0x80)
		    goto Lerr;			// trailing bytes are 10xxxxxx
		V = (V << 6) | (u & 0x3F);
	    }
	    if (!isValidDchar(V))
		goto Lerr;
	    i += n;
	}
	else
	{
	    V = cast(dchar) u;
	    i++;
	}

	idx = i;
	return V;

      Lerr:
	throw new Exception("4invalid UTF-8 sequence");
    }

unittest
{   size_t i;
    dchar c;

    debug(utf) printf("utf.decode.unittest\n");

    static char[] s1 = "abcd";
    i = 0;
    c = decode(s1, i);
    assert(c == cast(dchar)'a');
    assert(i == 1);
    c = decode(s1, i);
    assert(c == cast(dchar)'b');
    assert(i == 2);

    static char[] s2 = "\xC2\xA9";
    i = 0;
    c = decode(s2, i);
    assert(c == cast(dchar)'\u00A9');
    assert(i == 2);

    static char[] s3 = "\xE2\x89\xA0";
    i = 0;
    c = decode(s3, i);
    assert(c == cast(dchar)'\u2260');
    assert(i == 3);

    static char[][] s4 =
    [	"\xE2\x89",		// too short
	"\xC0\x8A",
	"\xE0\x80\x8A",
	"\xF0\x80\x80\x8A",
	"\xF8\x80\x80\x80\x8A",
	"\xFC\x80\x80\x80\x80\x8A",
    ];

    for (int j = 0; j < s4.length; j++)
    {
	try
	{
	    i = 0;
	    c = decode(s4[j], i);
	    assert(0);
	}
	catch (UtfException u)
	{
	    i = 23;
	    delete u;
	}
	assert(i == 23);
    }
}

/** ditto */

dchar decode(wchar[] s, inout size_t idx)
    in
    {
	assert(idx >= 0 && idx < s.length);
    }
    out (result)
    {
	assert(isValidDchar(result));
    }
    body
    {
	char[] msg;
	dchar V;
	size_t i = idx;
	uint u = s[i];

	if (u & ~0x7F)
	{   if (u >= 0xD800 && u <= 0xDBFF)
	    {   uint u2;

		if (i + 1 == s.length)
		{   msg = "surrogate UTF-16 high value past end of string";
		    goto Lerr;
		}
		u2 = s[i + 1];
		if (u2 < 0xDC00 || u2 > 0xDFFF)
		{   msg = "surrogate UTF-16 low value out of range";
		    goto Lerr;
		}
		u = ((u - 0xD7C0) << 10) + (u2 - 0xDC00);
		i += 2;
	    }
	    else if (u >= 0xDC00 && u <= 0xDFFF)
	    {   msg = "unpaired surrogate UTF-16 value";
		goto Lerr;
	    }
	    else if (u == 0xFFFE || u == 0xFFFF)
	    {   msg = "illegal UTF-16 value";
		goto Lerr;
	    }
	    else
		i++;
	}
	else
	{
	    i++;
	}

	idx = i;
	return cast(dchar)u;

      Lerr:
	throw new UtfException(msg, i);
    }

/** ditto */

dchar decode(dchar[] s, inout size_t idx)
    in
    {
	assert(idx >= 0 && idx < s.length);
    }
    body
    {
	size_t i = idx;
	dchar c = s[i];

	if (!isValidDchar(c))
	    goto Lerr;
	idx = i + 1;
	return c;

      Lerr:
	throw new UtfException("5invalid UTF-32 value", i);
    }



/* =================== Encode ======================= */

/*******************************
 * Encodes character c and appends it to array s[].
 */

void encode(inout char[] s, dchar c)
    in
    {
	assert(isValidDchar(c));
    }
    body
    {
	char[] r = s;

	if (c <= 0x7F)
	{
	    r ~= cast(char) c;
	}
	else
	{
	    char[4] buf;
	    uint L;

	    if (c <= 0x7FF)
	    {
		buf[0] = cast(char)(0xC0 | (c >> 6));
		buf[1] = cast(char)(0x80 | (c & 0x3F));
		L = 2;
	    }
	    else if (c <= 0xFFFF)
	    {
		buf[0] = cast(char)(0xE0 | (c >> 12));
		buf[1] = cast(char)(0x80 | ((c >> 6) & 0x3F));
		buf[2] = cast(char)(0x80 | (c & 0x3F));
		L = 3;
	    }
	    else if (c <= 0x10FFFF)
	    {
		buf[0] = cast(char)(0xF0 | (c >> 18));
		buf[1] = cast(char)(0x80 | ((c >> 12) & 0x3F));
		buf[2] = cast(char)(0x80 | ((c >> 6) & 0x3F));
		buf[3] = cast(char)(0x80 | (c & 0x3F));
		L = 4;
	    }
	    else
	    {
		assert(0);
	    }
	    r ~= buf[0 .. L];
	}
	s = r;
    }

unittest
{
    debug(utf) printf("utf.encode.unittest\n");

    char[] s = "abcd";
    encode(s, cast(dchar)'a');
    assert(s.length == 5);
    assert(s == "abcda");

    encode(s, cast(dchar)'\u00A9');
    assert(s.length == 7);
    assert(s == "abcda\xC2\xA9");
    //assert(s == "abcda\u00A9");	// BUG: fix compiler

    encode(s, cast(dchar)'\u2260');
    assert(s.length == 10);
    assert(s == "abcda\xC2\xA9\xE2\x89\xA0");
}

/** ditto */

void encode(inout wchar[] s, dchar c)
    in
    {
	assert(isValidDchar(c));
    }
    body
    {
	wchar[] r = s;

	if (c <= 0xFFFF)
	{
	    r ~= cast(wchar) c;
	}
	else
	{
	    wchar[2] buf;

	    buf[0] = cast(wchar) ((((c - 0x10000) >> 10) & 0x3FF) + 0xD800);
	    buf[1] = cast(wchar) (((c - 0x10000) & 0x3FF) + 0xDC00);
	    r ~= buf;
	}
	s = r;
    }

/** ditto */

void encode(inout dchar[] s, dchar c)
    in
    {
	assert(isValidDchar(c));
    }
    body
    {
	s ~= c;
    }