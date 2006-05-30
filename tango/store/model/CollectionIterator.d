/*
 File: CollectionIterator.d

 Originally written by Doug Lea and released into the public domain. 
 Thanks for the assistance and support of Sun Microsystems Labs, Agorics 
 Inc, Loral, and everyone contributing, testing, and using this code.

 History:
 Date     Who                What
 24Sep95  dl@cs.oswego.edu   Create from collections.d  working file

*/


module tango.store.model.CollectionIterator;

private import tango.store.model.Iterator;

/**
 *
 * CollectionIterator extends the standard java.util.Iterator
 * interface with two additional methods.
 * @author Doug Lea
 * @version 0.93
 *
 * <P> For an introduction to this package see <A HREF="index.html"> Overview </A>.
 *
**/

public interface CollectionIteratorT(T) : IteratorT!(T)
{

        /**
         * Return true if the collection that constructed this enumeration
         * has been detectably modified since construction of this enumeration.
         * Ability and precision of detection of this condition can vary
         * across collection class implementations.
         * more() is false whenever corrupted is true.
         *
         * @return true if detectably corrupted.
        **/

        public bool corrupted();

        /**
         * Return the number of elements in the enumeration that have
         * not yet been traversed. When corrupted() is true, this 
         * number may (or may not) be greater than zero even if more() 
         * is false. Exception recovery mechanics may be able to
         * use this as an indication that recovery of some sort is
         * warranted. However, it is not necessarily a foolproof indication.
         * <P>
         * You can also use it to pack enumerations into arrays. For example:
         * <PRE>
         * Object arr[] = new Object[e.numberOfRemainingElement()]
         * int i = 0;
         * while (e.more()) arr[i++] = e.value();
         * </PRE>
         * <P>
         * For the converse case, 
         * @see ArrayIterator
         * @return the number of untraversed elements
        **/

        public int remaining();
}

public interface CollectionMapIteratorT(K, T) : CollectionIteratorT!(T), MapIteratorT!(K, T) {}


alias CollectionIteratorT!(Object) CollectionIterator;