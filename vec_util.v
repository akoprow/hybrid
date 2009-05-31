Require Export Bvector.
Require Import Program.
Require Import Omega.
Require Import nat_util.
Require Import util.

Set Implicit Arguments.

Implicit Arguments Vnil [A].
Implicit Arguments Vcons.

Section vector.

Variable n : nat.
Variable A : Type.

Section Vnth.

  Program Fixpoint Vnth n (v : vector A n) : dom_lt n -> A :=
    match v with
    | Vnil => 
        fun ip => !
    | Vcons x p v' =>
        fun ip =>
          match dom_lt_val ip with
          | 0 => x
          | S j => Vnth v' (dom_build (i:=j) _)
          end
    end.

  Next Obligation.
  Proof.
    inversion ip. inversion H.
  Qed.
  Next Obligation.
  Proof.
    destruct ip. simpl in *. subst. auto with arith.
  Qed.

End Vnth.

Section Vbuild.

  Program Fixpoint Vbuild_spec n (gen : dom_lt n -> A) :
    { v : vector A n | forall (ip : dom_lt n), Vnth v ip = gen ip } :=
    match n with
    | 0 => Vnil
    | S p => 
        let gen' ip := gen (dom_build (i:=S (dom_lt_val ip)) _) in
          Vcons (gen (dom_build (i:=0) _)) (@Vbuild_spec p gen')
    end.

  Next Obligation.
  Proof.
    destruct ip. elimtype False. subst. omega.
  Qed.
  Next Obligation.
    destruct ip. simpl. omega.
  Qed.
  Next Obligation.
    omega.
  Qed.
  Next Obligation.
    destruct_call Vbuild_spec. simpl.
    destruct n0. discriminate.
    inversion Heq_n. subst.
    destruct ip.
    simplify_eqs. destruct x0. unfold dom_build. pi.
    rewrite e. unfold dom_build. pi.
  Defined.

  Program Definition Vbuild n gen : vector A n := Vbuild_spec gen.

End Vbuild.

Require Import List.

Section vec_of_list.

  Fixpoint vec_of_list (l : list A) : vector A (length l) :=
    match l with
    | nil => Vnil
    | cons x m => Vcons x (vec_of_list m)
    end.

End vec_of_list.

Section Vforall2.

  Variable R : A -> A -> Prop.

  Fixpoint Vforall2_aux n1 (v1 : vector A n1) n2 (v2 : vector A n2) {struct v1} : Prop :=
    match v1, v2 with
    | Vnil, Vnil => True
    | Vcons a _ v, Vcons b _ w => R a b /\ Vforall2_aux v w
    | _, _ => False
    end.

  Definition Vforall2 n (v1 v2 : vector A n) := Vforall2_aux v1 v2.

End Vforall2.

End vector.

Section VCheck_n.

  Variables 
    (n : nat) 
    (P : dom_lt n -> Prop).

  Program Fixpoint Vcheck_n_aux (p : nat | p <= n) 
    {measure (fun p => n - p) p} : Prop :=

    match le_lt_dec n p with
    | left _ => True
    | right cmp =>
        @P p /\ @Vcheck_n_aux (S p)
    end.

  Next Obligation.
  Proof.
    omega.
  Qed.

  Program Definition Vcheck_n := @Vcheck_n_aux 0.

  Next Obligation.
  Proof.
    omega.
  Qed.

End VCheck_n.