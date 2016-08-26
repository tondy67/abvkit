/***********************************************************************
*
*  Part of abvkit (haxe port of http://www.romanredz.se/Mouse/)
*
*  Copyright (c) 2016 by Todor Angelov (www.tondy.com).
*
*  Licensed under the Apache License, Version 2.0 (the "License");
*  you may not use this file except in compliance with the License.
*  You may obtain a copy of the License at
*
*       http://www.apache.org/licenses/LICENSE-2.0
*
*  Unless required by applicable law or agreed to in writing, software
*  distributed under the License is distributed on an "AS IS" BASIS,
*  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
*  See the License for the specific language governing permissions and
*  limitations under the License.
*
***********************************************************************/

package abv.peg;


//**********************************************************************
//
// A square matrix with boolean elements.
//
// A matrix of size 'n' has 'n' rows
// and 'n' columns.
// The rows and columns are numbered from '0' through 'n-1'.
// The element in row 'i' and column 'j' is referred to
// as the (i,j)-th element.
//
//**********************************************************************

@:dce
class BitMatrix{
//----------------------------------------------------------------------
// BitMatrix is implemented as an array 'm' of BitSets,
// each BitSet representing one row.
//----------------------------------------------------------------------
	var n:Int; // Size
	var m:Array<BitSet> = [];// The matrix

//----------------------------------------------------------------------
// Construct incomplete n by n matrix.
//----------------------------------------------------------------------
	public function new(n:Int)
	{
		this.n = n;
	}

//----------------------------------------------------------------------
// Constructs empty matrix.
//
// @paramn Size of the matrix.
// @return An 'n' by 'n' matrix
// with all elements '0'.
//----------------------------------------------------------------------
	public static function empty(n:Int)
	{
		var R = new BitMatrix(n);
		for (i in 0...n){
			R.m[i] = new BitSet(n);
		}
		return R;
	}

//----------------------------------------------------------------------
// Constructs unit matrix.
//
// @paramn Size of the matrix.
// @return An 'n' by 'n' matrix
// with all diagonal elements '1'
// and remaining elements '0'.
//----------------------------------------------------------------------
	public static function unit(n:Int)
	{
		var R = empty(n);
		for (i in 0...n) R.m[i].set(i);
		return R;
	}

//----------------------------------------------------------------------
// Obtains size of this matrix.
//
// @return Number of rows / columns.
//----------------------------------------------------------------------
	public function size()
	{ 
		return n; 
	}

//----------------------------------------------------------------------
// Obtains number of ones in this matrix.
//
// @return Number of ones.
//----------------------------------------------------------------------
	public function weight()
	{
		var w = 0;
		for (i in 0...n){
			w += m[i].cardinality();
		}
		return w;
	}

//----------------------------------------------------------------------
// Obtains the value of '(i,j)'-th element.
//
// @parami Row number.
// @paramj Column number.
// @return Value of the '(i,j)'-th element.
//----------------------------------------------------------------------
	public function at(i:Int, j:Int)
	{ 
		return m[i].get(j); 
	}

//----------------------------------------------------------------------
// Sets the '(i,j)'-th element to 'b'.
//
// @parami Row number.
// @paramj Column number.
// @paramb The value to be set.
//----------------------------------------------------------------------
	public function set(i:Int, j:Int, b=true)
	{ 
		m[i].set(j, b) ; 
	}

//----------------------------------------------------------------------
// Obtains the contents of row 'r' as a BitSet.
//
// @paramr Row number.
// @return The contents of row 'r' as a BitSet.
//----------------------------------------------------------------------
	public function row(r:Int)
	{ 
		return m[r].copy(); 
	}

//----------------------------------------------------------------------
// Obtains the contents of column 'c' as a BitSet.
//
// @paramc Column number.
// @return The contents of column 'c' as a BitSet.
//----------------------------------------------------------------------
	public function column(c:Int)
	{
		var col = new Array<Bool>();
		for (i in 0...n) col[i] = m[i].get(c);
		return col;
	}

//----------------------------------------------------------------------
// Constructs a copy of this matrix.
//
// @return New matrix, identical to this matrix.
//----------------------------------------------------------------------
	public function copy()
	{
		var R = new BitMatrix(n);
		for (i in 0...n) R.m[i] = m[i].copy();
		return R;
	}

//----------------------------------------------------------------------
// Constructs transpose of this matrix.
//
// @return New matrix that is the transpose of this matrix.
//----------------------------------------------------------------------
	public function transpose()
	{
		var R = empty(n);
		for (i in 0...n)
		for (j in 0...n)
		if (at(i,j)) R.set(j,i);
		return R;
	}

//----------------------------------------------------------------------
// Computes transitve closure of this matrix.
// The matrix is considered to represent a relation 'R'
// within a set of 'n' objects, where 'n'
// is the size of the matrix.
// The resulting matrix represents the transitive closure of 'R'.
// 
// The result is computed using Warshall's algorithm.
// See J-P.Tremblay and P.G.Sorenson, The Theory and Practice of Compiler Writing,
// page 25.
//
// @return New matrix that is the transitive closure of this matrix.
//----------------------------------------------------------------------
	public function closure()
	{
		var M = copy();
		for (k in 0...n){
			for (i in 0...n){
				if (M.at(i,k)) M.m[i].or(M.m[k]);
			}
		}
		return M;
	}

//----------------------------------------------------------------------
// Computes transitve and reflexive closure of this matrix.
// (Such closure of M is often denoted by M*.)
//
// @return New matrix that is the transitive and reflexive closure of this matrix.
//----------------------------------------------------------------------
	public function star()
	{ 
		return closure().or(unit(n)); 
	}

//----------------------------------------------------------------------
// Modifies a specified matrix by performing
// the element-by-element 'or' with this matrix.
//
// @paramM A bit matrix of the same size as this.
//----------------------------------------------------------------------
	public function orInto( M:BitMatrix)
	{
		if (M.n != n) throw "size mismatch " + M.n + " != " + n;
		for (i in 0...n) M.m[i].or(m[i]);
	}

//----------------------------------------------------------------------
// Modifies a specified matrix by performing
// the element-by-element 'and' with this matrix.
//
// @paramM A bit matrix of the same size as this.
//----------------------------------------------------------------------
	public function andInto(M:BitMatrix)
	{
		if (M.n != n) throw "size mismatch " + M.n + " != " + n;
		for (i in 0...n) M.m[i].and(m[i]);
	}

//----------------------------------------------------------------------
// Computes element-by-element 'or' of this matrix and the specified matrix.
//
// @paramM A bit matrix of the same size as this.
// @return New matrix that is the element-by-element 'or'
// of this matrix and 'M'.
//----------------------------------------------------------------------
	public function or(M:BitMatrix)
	{
		if (M.n != n) throw "size mismatch " + M.n + " != " + n;
		var R = copy();
		M.orInto(R);
		return R;
	}

//----------------------------------------------------------------------
// Computes element-by-element 'and' of this matrix and the specified matrix.
//
// @paramM A bit matrix of the same size as this.
// @return New matrix that is the element-by-element 'and'
// of this matrix and 'M'.
//----------------------------------------------------------------------
	public function and(M:BitMatrix)
	{
		if (M.n != n) throw "size mismatch " + M.n + " != " + n;
		var R = copy();
		M.andInto(R);
		return R;
	}

//----------------------------------------------------------------------
// Computes element-by-element 'not' of this matrix.
//
// @return New matrix that is the element-by-element 'not'
// of this matrix.
//----------------------------------------------------------------------
	public function not()
	{
		var R = copy();
		for (i in 0...n) R.m[i].flip(0,n);
		return R;
	}

//----------------------------------------------------------------------
// Computes product of this matrix and the specified matrix.
// The product is defined as for numeric matrices, with logical 'or'
// instead of addition and logical 'and' instead of multiplication.
//
// @paramM A bit matrix of the same size as this.
// @return New matrix that is the product
// of this matrix and 'M'.
//----------------------------------------------------------------------
	public function times( M:BitMatrix)
	{
		if (M.n != n) throw "size mismatch " + M.n + " != " + n;
		var R = empty(n);
		var T = M.transpose();
		for (i in 0...n){
			for (j in 0...n){
				if (m[i].intersects(T.m[j])) R.set(i,j);
			}
		}
		return R;
	}

//----------------------------------------------------------------------
//
// Computes product of this matrix and the specified vector.
// The product is defined as for numeric matrices, with logical 'or'
// instead of addition and logical 'and' instead of multiplication.
//
// @paramV A bit vector of the same size as this.
// @return New matrix that is the product
// of this matrix and 'V'.
//----------------------------------------------------------------------
	public function timesVector( V:BitSet)
	{
		var R = new BitSet(n);
		for (i in 0...n){
			if (m[i].intersects(V)) R.set(i);
		}
		return R;
	}

//----------------------------------------------------------------------
// Computes n by n matrix as the Crtesian product of two vectors.
//
// @paramV1 A bit vector.
// @paramV2 A bit vector.
// @paramnDimension of the result.
// @return New matrix that is the product of 'V1'
// and 'V2'.
//----------------------------------------------------------------------
	public static function product( V1:BitSet,V2:BitSet, n:Int)
	{
		var M = new BitMatrix(n);
		for (i in 0...n){
			if (V1.get(i)) M.m[i] = V2.copy();
			else M.m[i] = new BitSet(n);
		}
		return M;
	}

//----------------------------------------------------------------------
// Replaces a square area of this matrix by the contents of
// another matrix.
//
// @paramM The matrix to be inserted.
// @parami starting row of the area to be replaced.
// @paramj starting column of the area to be replaced.
// @return This matrix with modified contents.
//----------------------------------------------------------------------

	public function insert( M:BitMatrix, i:Int, j:Int)
	{
		if (i+M.n>n || j+M.n>n)	throw "Insertion overflow";
		for (r in 0...M.n){
			var src = M.m[r];
			var trg = m[i+r];
			for (c in 0...M.n) trg.set(c+j,src.get(c));
		}
		return this;
	}

//----------------------------------------------------------------------
// Returns a square matrix cut out from this matrix.
//
// @params Size of the resulting matrix.
// @parami starting row of the area to be cut.
// @paramj starting column of the area to be cut.
// @return New 'n' by 'n' matrix.
//----------------------------------------------------------------------
	public function cut(s:Int, i:Int, j:Int)
	{
		if ((s<=0) || (s>n)) throw "s = " + s;
		if ((i+s>n) || (j+s>n)) throw "Cut overflow";
		var M = empty(s);
		for (r in 0...s) {
			var src = m[i+r];
			var trg = M.m[r];
			for ( c in 0...s) trg.set(c,src.get(c+j));
		}
		return M;
	}

//----------------------------------------------------------------------
// Writes this matrix to 'System.out'.
//----------------------------------------------------------------------
	public function show()
	{
		for (i in 0...n){
			var sb = new StringBuf();
			for (j in 0...n) sb.add(this.at(i,j)? 1:0);
			sb.add(" ");
			Sys.println(sb+"");
		}
	}

//----------------------------------------------------------------------
// Test
//----------------------------------------------------------------------

	public static function test()
	{
		var P = empty(4);

		P.set(0,1);
		P.set(1,2);
		P.set(2,3);

		var Q = unit(6);
		Q.insert(P,1,2);
		Q.show();

		Q.cut(4,1,2).show();

		Sys.println("\nP:");
		P.show();
		Sys.println("\nweight of P = " + P.weight());

		Sys.println("\ncopy of P:");
		P.copy().show();

		Sys.println("\nP times P:");
		P.times(P).show();

		Sys.println("\nclosure of P:");
		P.closure().show();

		Sys.println("\nstar of P:");
		P.star().show();

		Sys.println("\nnot of P:");
		P.not().show();

		Sys.println("\ntranspose of P:");
		var R = P.transpose();
		R.show();

		Sys.println("\nP and closure of P:");
		P.and(P.closure()).show();

		Sys.println("\nP or transpose of P:");
		P.or(R).show();

		Sys.println("\nunit(3):");
		unit(3).show();

		var V = new BitSet(2);
		V.set(1);
		V.set(2);

		var W = new BitSet(3);
		W.set(0);
		W.set(3);

		Sys.println("\nV:");
		Sys.println(V);

		Sys.println("\nW:");
		Sys.println(W);

		Sys.println("\nP times V:");
		Sys.println(P.timesVector(V));

		Sys.println("\nV product W:");
		product(V,W,4).show(); 
	}
}

class BitSet{
	var a:Array<Bool>;
	 
	public function new(n:Int)
	{
		a = new Array<Bool>();
		for (i in 0...n) a[i] = false;
	}

	public function get(n:Int)
	{
		return a[n];
	}

	public function set(n:Int, v=true)
	{
		a[n] = v;
	}

	public function copy()
	{
		var r = new BitSet(a.length);
		for (i in 0...a.length) r.set(i,a[i]);
		return r;
	}

	public function cardinality()
	{
		var r = 0;
		for (it in a) if (it) r++;
		return r;
	}// cardinality()

	public function intersects(v:BitSet)
	{
		var r = false;
		for (i in 0...a.length){
			if (a[i] && v.get(i)){
				r = true;
				break;
			}
		}
		return r;
	}// intersects()

	public function flip(from:Int, to=0)
	{
		if (to == 0) to = from + 1;
		for (i in from...to){
			a[i] = !a[i];
		}
	}// flip()

	public function and(v:BitSet)
	{
		for (i in 0...a.length){
			a[i] = a[i] && v.get(i);
		}
	}// and()

	public function or(v:BitSet)
	{
		for (i in 0...a.length){
			a[i] = a[i] || v.get(i);
		}
	}// or()

	public function isEmpty()
	{
		var r = false;
		for (it in a){
			if (it){
				r = true;
				break;
			}
		}
		return r;
	}// isEmpty()

}
