(************************************************************************)
(*  v      *   The Coq Proof Assistant  /  The Coq Development Team     *)
(* <O___,, * CNRS-Ecole Polytechnique-INRIA Futurs-Universite Paris Sud *)
(*   \VV/  **************************************************************)
(*    //   *      This file is distributed under the terms of the       *)
(*         *       GNU Lesser General Public License Version 2.1        *)
(************************************************************************)

(*i $Id$ i*)

(** Tactics related to (dependent) equality and proof irrelevance. *)

Require Export ProofIrrelevance.
Require Export JMeq.

Require Import Coq.Program.Tactics.
Require Export Equations.Init.
Require Import Equations.Signature.
Require Import Equations.EqDec.

Ltac is_ground_goal := 
  match goal with
    |- ?T => is_ground T
  end.

(** Try to find a contradiction. *)

(* Hint Extern 10 => is_ground_goal ; progress (elimtype False). *)

(** We will use the [block] definition to separate the goal from the 
   equalities generated by the tactic. *)

Definition block {A : Type} (a : A) := a.

Ltac block_goal := match goal with [ |- ?T ] => change (block T) end.
Ltac unblock_goal := unfold block in *.

(** Notation for heterogenous equality. *)

Notation " x ~= y " := (@JMeq _ x _ y) (at level 70, no associativity).

(** Notation for the single element of [x = x] and [x ~= x]. *)

Implicit Arguments eq_refl [[A] [x]].
Implicit Arguments JMeq_refl [[A] [x]].

(** Do something on an heterogeneous equality appearing in the context. *)

Ltac on_JMeq tac :=
  match goal with
    | [ H : @JMeq ?x ?X ?y ?Y |- _ ] => tac H
  end.

(** Try to apply [JMeq_eq] to get back a regular equality when the two types are equal. *)

Ltac simpl_one_JMeq :=
  on_JMeq ltac:(fun H => apply JMeq_eq in H).

(** Repeat it for every possible hypothesis. *)

Ltac simpl_JMeq := repeat simpl_one_JMeq.

(** Just simplify an h.eq. without clearing it. *)

Ltac simpl_one_dep_JMeq :=
  on_JMeq
  ltac:(fun H => let H' := fresh "H" in
    assert (H' := JMeq_eq H)).

Require Import Eqdep.

(** Simplify dependent equality using sigmas to equality of the second projections if possible.
   Uses UIP. *)

Ltac simpl_existT :=
  match goal with
    [ H : existT _ ?x _ = existT _ ?x _ |- _ ] =>
    let Hi := fresh H in assert(Hi:=inj_pairT2 _ _ _ _ _ H) ; clear H
  end.

Ltac simpl_existTs := repeat simpl_existT.

(** Tries to eliminate a call to [eq_rect] (the substitution principle) by any means available. *)

Ltac elim_eq_rect :=
  match goal with
    | [ |- ?t ] =>
      match t with
        | context [ @eq_rect _ _ _ _ _ ?p ] =>
          let P := fresh "P" in
            set (P := p); simpl in P ;
	      ((case P ; clear P) || (clearbody P; rewrite (UIP_refl _ _ P); clear P))
        | context [ @eq_rect _ _ _ _ _ ?p _ ] =>
          let P := fresh "P" in
            set (P := p); simpl in P ;
	      ((case P ; clear P) || (clearbody P; rewrite (UIP_refl _ _ P); clear P))
      end
  end.

(** Rewrite using uniqueness of indentity proofs [H = eq_refl]. *)

Ltac simpl_uip :=
  match goal with
    [ H : ?X = ?X |- _ ] => rewrite (UIP_refl _ _ H) in *; clear H
  end.

(** Simplify equalities appearing in the context and goal. *)

Ltac simpl_eq := simpl ; unfold eq_rec_r, eq_rec ; repeat (elim_eq_rect ; simpl) ; repeat (simpl_uip ; simpl).

(** Try to abstract a proof of equality, if no proof of the same equality is present in the context. *)

Ltac abstract_eq_hyp H' p :=
  let ty := type of p in
  let tyred := eval simpl in ty in
    match tyred with
      ?X = ?Y =>
      match goal with
        | [ H : X = Y |- _ ] => fail 1
        | _ => set (H':=p) ; try (change p with H') ; clearbody H' ; simpl in H'
      end
    end.

(** Apply the tactic tac to proofs of equality appearing as coercion arguments.
   Just redefine this tactic (using [Ltac on_coerce_proof tac ::=]) to handle custom coercion operators.
   *)

Ltac on_coerce_proof tac T :=
  match T with
    | context [ eq_rect _ _ _ _ ?p ] => tac p
  end.

Ltac on_coerce_proof_gl tac :=
  match goal with
    [ |- ?T ] => on_coerce_proof tac T
  end.

(** Abstract proofs of equalities of coercions. *)

Ltac abstract_eq_proof := on_coerce_proof_gl ltac:(fun p => let H := fresh "eqH" in abstract_eq_hyp H p).

Ltac abstract_eq_proofs := repeat abstract_eq_proof.

(** Factorize proofs, by using proof irrelevance so that two proofs of the same equality
   in the goal become convertible. *)

Ltac pi_eq_proof_hyp p :=
  let ty := type of p in
  let tyred := eval simpl in ty in
  match tyred with
    ?X = ?Y =>
    match goal with
      | [ H : X = Y |- _ ] =>
        match p with
          | H => fail 2
          | _ => rewrite (proof_irrelevance (X = Y) p H)
        end
      | _ => fail " No hypothesis with same type "
    end
  end.

(** Factorize proofs of equality appearing as coercion arguments. *)

Ltac pi_eq_proof := on_coerce_proof_gl pi_eq_proof_hyp.

Ltac pi_eq_proofs := repeat pi_eq_proof.

(** The two preceding tactics in sequence. *)

Ltac clear_eq_proofs :=
  abstract_eq_proofs ; pi_eq_proofs.

Hint Rewrite <- eq_rect_eq : refl_id.

(** The [refl_id] database should be populated with lemmas of the form
   [coerce_* t eq_refl = t]. *)

Lemma JMeq_eq_refl {A} (x : A) : JMeq_eq (@JMeq_refl _ x) = eq_refl.
Proof. intros. apply proof_irrelevance. Qed.

Lemma UIP_refl_refl : forall A (x : A),
  Eqdep.EqdepTheory.UIP_refl A x eq_refl = eq_refl.
Proof. intros. apply UIP_refl. Qed.

Lemma inj_pairT2_refl : forall A (x : A) (P : A -> Type) (p : P x),
  Eqdep.EqdepTheory.inj_pairT2 A P x p p eq_refl = eq_refl.
Proof. intros. apply UIP_refl. Qed.

Hint Rewrite @JMeq_eq_refl @UIP_refl_refl @inj_pairT2_refl : refl_id.

Ltac rewrite_refl_id := autorewrite with refl_id.

(** Clear the context and goal of equality proofs. *)

Ltac clear_eq_ctx :=
  rewrite_refl_id ; clear_eq_proofs.

(** Reapeated elimination of [eq_rect] applications.
   Abstracting equalities makes it run much faster than an naive implementation. *)

Ltac simpl_eqs :=
  repeat (elim_eq_rect ; simpl ; clear_eq_ctx).

(** Clear unused reflexivity proofs. *)

Ltac clear_refl_eq :=
  match goal with [ H : ?X = ?X |- _ ] => clear H end.
Ltac clear_refl_eqs := repeat clear_refl_eq.

(** Clear unused equality proofs. *)

Ltac clear_eq :=
  match goal with [ H : _ = _ |- _ ] => clear H end.
Ltac clear_eqs := repeat clear_eq.

(** Combine all the tactics to simplify goals containing coercions. *)

Ltac simplify_eqs :=
  simpl ; simpl_eqs ; clear_eq_ctx ; clear_refl_eqs ;
    try subst ; simpl ; repeat simpl_uip ; rewrite_refl_id.

(** A tactic that tries to remove trivial equality guards in induction hypotheses coming
   from [dependent induction]/[generalize_eqs] invocations. *)

Ltac simplify_IH_hyps := repeat
  match goal with
    | [ hyp : _ |- _ ] => specialize_eqs hyp
  end.

(** We split substitution tactics in the two directions depending on which 
   names we want to keep corresponding to the generalization performed by the
   [generalize_eqs] tactic. *)

Ltac subst_left_no_fail :=
  repeat (match goal with
            [ H : ?X = ?Y |- _ ] => subst X
          end).

Ltac subst_right_no_fail :=
  repeat (match goal with
            [ H : ?X = ?Y |- _ ] => subst Y
          end).

Ltac inject_left H :=
  progress (inversion H ; subst_left_no_fail ; clear_dups) ; clear H.

Ltac inject_right H :=
  progress (inversion H ; subst_right_no_fail ; clear_dups) ; clear H.

Ltac autoinjections_left := repeat autoinjection ltac:inject_left.
Ltac autoinjections_right := repeat autoinjection ltac:inject_right.

Ltac simpl_depind := subst_no_fail ; autoinjections ; try discriminates ; 
  simpl_JMeq ; simpl_existTs ; simplify_IH_hyps.

Ltac simpl_depind_l := subst_left_no_fail ; autoinjections_left ; try discriminates ; 
  simpl_JMeq ; simpl_existTs ; simplify_IH_hyps.

Ltac simpl_depind_r := subst_right_no_fail ; autoinjections_right ; try discriminates ; 
  simpl_JMeq ; simpl_existTs ; simplify_IH_hyps.

(** Support for the [Equations] command.
   These tactics implement the necessary machinery to solve goals produced by the
   [Equations] command relative to dependent pattern-matching.
   It is completely inspired from the "Eliminating Dependent Pattern-Matching" paper by
   Goguen, McBride and McKinna. *)


(** The NoConfusionPackage class provides a method for making progress on proving a property
   [P] implied by an equality on an inductive type [I]. The type of [noConfusion] for a given
   [P] should be of the form [ Π Δ, (x y : I Δ) (x = y) -> NoConfusion P x y ], where
   [NoConfusion P x y] for constructor-headed [x] and [y] will give a formula ending in [P].
   This gives a general method for simplifying by discrimination or injectivity of constructors.

   Some actual instances are defined later in the file using the more primitive [discriminate] and
   [injection] tactics on which we can always fall back.
   *)

Class NoConfusionPackage (A : Type) := {
  NoConfusion : Type -> A -> A -> Type;
  noConfusion : forall P a b, a = b -> NoConfusion P a b
}.

(** Apply [noConfusion] on a given hypothsis. *)

Ltac noconf_ref H :=
  match type of H with
    ?R ?A ?X ?Y =>
    match goal with
      [ |- ?P ] =>
      let H' := fresh in assert (H':=noConfusion (A:=A) P X Y H) ;
        apply H' ; clear H' H 
    end
  end.

Ltac blocked t := block_goal ; t ; unblock_goal.

Ltac noconf H := blocked ltac:(noconf_ref H ; intros).

(** The [DependentEliminationPackage] provides the default dependent elimination principle to
   be used by the [equations] resolver. It is especially useful to register the dependent elimination
   principles for things in [Prop] which are not automatically generated. *)

Class DependentEliminationPackage (A : Type) :=
  { elim_type : Type ; elim : elim_type }.

(** A higher-order tactic to apply a registered eliminator. *)

Ltac elim_tac tac p :=
  let ty := type of p in
  let eliminator := eval simpl in (elim (A:=ty)) in
    tac p eliminator.

(** Specialization to do case analysis or induction.
   Note: the [equations] tactic tries [case] before [elim_case]: there is no need to register
   generated induction principles. *)

Ltac elim_case p := elim_tac ltac:(fun p el => destruct p using el) p.
Ltac elim_ind p := elim_tac ltac:(fun p el => induction p using el) p.

(** Lemmas used by the simplifier, mainly rephrasings of [eq_rect], [eq_ind]. *)

Lemma solution_left : ∀ A (B : A -> Type) (t : A), B t -> (∀ x, x = t -> B x).
Proof. intros; subst. apply X. Defined.

Lemma solution_right : ∀ A (B : A -> Type) (t : A), B t -> (∀ x, t = x -> B x).
Proof. intros; subst; apply X. Defined.

Lemma solution_left_let : ∀ A (B : A -> Type) (b : A) (t : A), 
  (b = t -> B t) -> (let x := b in x = t -> B x).
Proof. intros; subst. subst b. apply X. reflexivity. Defined.

Lemma solution_right_let : ∀ A (B : A -> Type) (b t : A), 
  (t = b -> B t) -> (let x := b in t = x -> B x).
Proof. intros; subst; apply X. reflexivity. Defined.

Lemma deletion : ∀ A B (t : A), B -> (t = t -> B).
Proof. intros; assumption. Defined.

Lemma simplification_heq : ∀ A B (x y : A), (x = y -> B) -> (JMeq x y -> B).
Proof. intros; apply X; apply (JMeq_eq H). Defined.

Lemma simplification_existT2 : ∀ A (P : A -> Type) B (p : A) (x y : P p),
  (x = y -> B) -> (existT P p x = existT P p y -> B).
Proof. intros. apply X. apply inj_pair2. exact H. Defined.

(** If we have decidable equality on [A] we use this version which is 
   axiom-free! *)

Lemma simplification_existT2_dec : ∀ {A} `{EqDec A} (P : A -> Type) B (p : A) (x y : P p),
  (x = y -> B) -> (existT P p x = existT P p y -> B).
Proof. intros. apply X. apply inj_right_pair in H0. assumption. Defined.

Lemma simplification_existT1 : ∀ A (P : A -> Type) B (p q : A) (x : P p) (y : P q),
  (p = q -> existT P p x = existT P q y -> B) -> (existT P p x = existT P q y -> B).
Proof. intros. injection H. intros ; auto. Defined.
  
Lemma simplification_K : ∀ A (x : A) (B : x = x -> Type), B eq_refl -> (∀ p : x = x, B p).
Proof. intros. rewrite (UIP_refl A). assumption. Defined.

Lemma simplification_K_dec : ∀ {A} `{EqDec A} (x : A) (B : x = x -> Type), 
  B eq_refl -> (∀ p : x = x, B p).
Proof. intros. apply K_dec. assumption. Defined.

(** This hint database and the following tactic can be used with [autounfold] to 
   unfold everything to [eq_rect]s. *)

Hint Unfold solution_left solution_right deletion simplification_heq
  simplification_existT1 simplification_existT2 simplification_K
  simplification_K_dec simplification_existT2_dec
  eq_rect_r eq_rec eq_ind : equations.

(** Simply unfold as much as possible. *)

Ltac unfold_equations := repeat progress autounfold with equations.
Ltac unfold_equations_in H := repeat progress autounfold with equations in H.

(** The tactic [simplify_equations] is to be used when a program generated using [Equations] 
   is in the goal. It simplifies it as much as possible, possibly using [K] if needed.
   The argument is the concerned equation. *) 

Ltac simplify_equations f := repeat ((unfold_equations ; simplify_eqs ; 
  try autounfoldify f) || autorewrite with equations). 

Ltac simplify_equations_in e :=
  repeat progress (autounfold with equations in e ; simpl in e).

(** Using these we can make a simplifier that will perform the unification
   steps needed to put the goal in normalised form (provided there are only
   constructor forms). Compare with the lemma 16 of the paper.
   We don't have a [noCycle] procedure yet. *)

(* Ltac simplify_one_dep_elim_term c := *)
(*   match c with *)
(*     | @JMeq _ _ _ _ -> _ => refine (simplification_heq _ _ _ _ _) *)
(*     | ?t = ?t -> _ => intros _ || refine (simplification_K _ t _ _) *)
(*     | eq (existT _ _ _) (existT _ _ _) -> _ => *)
(*       refine (simplification_existT2 _ _ _ _ _ _ _) || *)
(*         refine (simplification_existT1 _ _ _ _ _ _ _ _) *)
(*     | forall H : ?x = ?y, _ => (* variables case *) *)
(*       (let hyp := fresh H in intros hyp ; *)
(*         move hyp before x ; move x before hyp; revert_until x; revert x; *)
(*           (match goal with *)
(*              | |- let x := _ in _ = _ -> @?B x => *)
(*                refine (solution_left_let _ B _ _ _) *)
(*              | _ => refine (solution_left _ _ _ _) *)
(*            end)) || *)
(*       (let hyp := fresh "Heq" in intros hyp ; *)
(*         move hyp before y ; move y before hyp; revert_until y; revert y; *)
(*           (match goal with *)
(*              | |- let x := _ in _ = _ -> @?B x => *)
(*                refine (solution_right_let _ B _ _ _) *)
(*              | _ => refine (solution_right _ _ _ _) *)
(*            end)) *)
(*     | forall H : ?f ?x = ?g ?y, _ => let H := fresh H in progress (intros H ; injection H ; clear H) *)
(*     | forall H : ?t = ?u, _ => let H := fresh H in *)
(*       intros hyp ; exfalso ; discriminate *)
(*     | forall H : ?x = ?y, _ => let hyp := fresh H in *)
(*       intros hyp ; (try (clear hyp ; (* If non dependent, don't clear it! *) fail 1)) ; *)
(*         case hyp ; clear hyp *)
(*     | block ?T => fail 1 (* Do not put any part of the rhs in the hyps *) *)
(*     | forall x, ?B => let ty := type of B in *)
(*       intro || (let H := fresh in intro H) *)
(*     | forall x, _ => *)
(*       let H := fresh x in rename x into H ; intro x (* Try to keep original names *) *)
(*     | _ => intro *)
(*   end. *)

Ltac simplify_one_dep_elim_term c :=
  match c with
    | @JMeq _ _ _ _ -> _ => refine (simplification_heq _ _ _ _ _)
    | ?t = ?t -> _ => intros _ || apply simplification_K_dec || refine (simplification_K _ t _ _)
    | (@existT ?A ?P ?n ?x) = (@existT ?A ?P ?n ?y) -> ?B =>
      apply (simplification_existT2_dec (A:=A) P B n x y) ||
        refine (simplification_existT2 _ _ _ _ _ _ _)
    | eq (existT _ _ _) (existT _ _ _) -> _ =>
      refine (simplification_existT1 _ _ _ _ _ _ _ _)
    | forall H : ?x = ?y, _ => (* variables case *)
      (let hyp := fresh H in intros hyp ;
        move hyp before x ; move x before hyp; revert_until x; revert x;
          (match goal with
             | |- let x := _ in _ = _ -> @?B x =>
               refine (solution_left_let _ B _ _ _)
             | _ => refine (solution_left _ _ _ _)
           end)) ||
      (let hyp := fresh "Heq" in intros hyp ;
        move hyp before y ; move y before hyp; revert_until y; revert y;
          (match goal with
             | |- let x := _ in _ = _ -> @?B x =>
               refine (solution_right_let _ B _ _ _)
             | _ => refine (solution_right _ _ _ _)
           end))
    | @eq ?A ?t ?u -> ?P => let hyp := fresh in intros hyp ; noconf_ref hyp
    | ?f ?x = ?g ?y -> _ => let H := fresh in progress (intros H ; injection H ; clear H)
    | ?t = ?u -> _ => let hyp := fresh in
      intros hyp ; elimtype False ; discriminate
    | ?x = ?y -> _ => let hyp := fresh in
      intros hyp ; (try (clear hyp ; (* If non dependent, don't clear it! *) fail 1)) ;
        case hyp ; clear hyp
    | block ?T => fail 1 (* Do not put any part of the rhs in the hyps *)
    | forall x, ?B => let ty := type of B in (* Works only with non-dependent products *)
      intro || (let H := fresh in intro H)
    | forall x, _ =>
      let H := fresh x in rename x into H ; intro x (* Try to keep original names *)
    | _ => intro

    (* | _ -> ?T => intro; try (let x := type of T in idtac) *)
    (*    (* Only really anonymous, non dependent hyps get automatically generated names. *) *)
    (* | forall x, _ => intro x || (let H := fresh x in rename x into H ; intro x) (* Try to keep original names *) *)
    (* | _ -> _ => intro *)
  end.

Ltac simplify_one_dep_elim :=
  match goal with
    | [ |- ?gl ] => simplify_one_dep_elim_term gl
  end.

(** Repeat until no progress is possible. By construction, it should leave the goal with
   no remaining equalities generated by the [generalize_eqs] tactic. *)

Ltac simplify_dep_elim := repeat simplify_one_dep_elim.

(** Reverse and simplify. *)

Ltac simpdep := reverse; simplify_dep_elim.

(** The default implementation of generalization using JMeq. *)

Ltac generalize_by_eqs id := generalize_eqs id.
Ltac generalize_by_eqs_vars id := generalize_eqs_vars id.

(** Do dependent elimination of the last hypothesis, but not simplifying yet
   (used internally). *)

Ltac destruct_last :=
  on_last_hyp ltac:(fun id => simpl in id ; generalize_by_eqs id ; destruct id).

(** The rest is support tactics for the [Equations] command. *)

(** Notation for inaccessible patterns. *)

Definition inaccessible_pattern {A : Type} (t : A) := t.

Notation "?( t )" := (inaccessible_pattern t).

Definition hide_pattern {A : Type} (t : A) := t.

Definition add_pattern {B} (A : Type) (b : B) := A.

(** To handle sections, we need to separate the context in two parts:
   variables introduced by the section and the rest. We introduce a dummy variable
   between them to indicate that. *)

CoInductive end_of_section := the_end_of_the_section.

Ltac set_eos := let eos := fresh "eos" in
  assert (eos:=the_end_of_the_section).

(** We have a specialized [reverse_local] tactic to reverse the goal until the begining of the
   section variables *)

Ltac reverse_local :=
  match goal with
    | [ H : ?T |- _ ] =>
      match T with
        | end_of_section => idtac
        | _ => revert H ; reverse_local 
      end
    | _ => idtac
  end.

Ltac clear_local :=
  match goal with
    | [ H : ?T |- _ ] =>
      match T with
        | end_of_section => idtac
        | _ => clear H ; clear_local 
      end
    | _ => idtac
  end.

(** Do as much as possible to apply a method, trying to get the arguments right.
   !!Unsafe!! We use [auto] for the [_nocomp] variant of [Equations], in which case some
   non-dependent arguments of the method can remain after [apply]. *)

Ltac simpl_intros m := ((apply m || refine m) ; auto) || (intro ; simpl_intros m).

(** Hopefully the first branch suffices. *)

Ltac try_intros m :=
  solve [ (intros ; unfold block ; refine m || (unfold block ; apply m)) ; auto ] ||
  solve [ unfold block ; simpl_intros m ] ||
  solve [ unfold block ; intros ; rapply m ; eauto ].

(** To solve a goal by inversion on a particular target. *)

Ltac do_empty id :=
  elimtype False ; simpl in id ;
  solve [ generalize_by_eqs id ; destruct id ; simplify_dep_elim
    | apply id ; eauto with Below ].

Ltac solve_empty target :=
  do_nat target intro ; on_last_hyp ltac:do_empty.

Ltac simplify_method tac := repeat (tac || simplify_one_dep_elim) ; reverse_local.

Ltac clear_fix_protos n tac :=
  match goal with
    | [ |- fix_proto _ -> _ ] => intros _ ; 
      match n with
        | O => fail 2 "clear_fix_proto: tactic would apply on prototype"
        | S ?n => clear_fix_protos n tac
      end
    | [ |- block _ ] => reverse_local ; tac n
    | _ => reverse_local ; tac n
  end.

(** Solving a method call: we can solve it by splitting on an empty family member
   or we must refine the goal until the body can be applied. *)

Ltac solve_method rec :=
  match goal with
    | [ H := ?body : nat |- _ ] => subst H ; clear ; clear_fix_protos body
      ltac:(fun n => abstract (simplify_method idtac ; solve_empty n))
    | [ H := ?body : ?T |- _ ] => clear H ; simplify_method ltac:(exact body) ; rec ; 
      try (exact (body : T)) ; try_intros (body:T)
  end.

(** Impossible cases, by splitting on a given target. *)

Ltac solve_split :=
  match goal with 
    | [ |- let split := ?x : nat in _ ] => intros _ ;
      clear_fix_protos x ltac:(fun n => clear ; abstract (solve_empty n))
  end.

(** If defining recursive functions, the prototypes come first. *)

Ltac intro_prototypes :=
  match goal with
    | [ |- ∀ x : _, _ ] => intro ; intro_prototypes
    | _ => idtac
  end.

Ltac introduce p := first [
  match p with _ => (* Already there, generalize dependent hyps *)
    generalize dependent p ; intros p
  end
  | intros until p | intros until 1 | intros ].

Ltac do_case p := introduce p ; (elim_case p || destruct p || (case p ; clear p)).
Ltac do_ind p := introduce p ; (elim_ind p || induction p).

Ltac case_last := block_goal ;
  on_last_hyp ltac:(fun p => 
    let ty := type of p in
      match ty with
        | ?x = ?x => revert p ; refine (simplification_K _ x _ _)
        | ?x = ?y => revert p
        | _ => simpl in p ; try simplify_equations_in p ; generalize_by_eqs p ; do_case p
      end).

Ltac nonrec_equations :=
  solve [solve_equations (case_last) (solve_method idtac)] || solve [ solve_split ]
    || fail "Unnexpected equations goal".

Ltac recursive_equations :=
  solve [solve_equations (case_last) (solve_method ltac:intro)] || solve [ solve_split ]
    || fail "Unnexpected recursive equations goal".

(** The [equations] tactic is the toplevel tactic for solving goals generated
   by [Equations]. *)

Ltac equations := set_eos ;
  match goal with
    | [ |- ∀ x : _, _ ] => intro ; recursive_equations
    | [ |- let x := _ in ?T ] => intro x ; exact x
    | _ => nonrec_equations
  end.

(** The following tactics allow to do induction on an already instantiated inductive predicate
   by first generalizing it and adding the proper equalities to the context, in a maner similar to
   the BasicElim tactic of "Elimination with a motive" by Conor McBride. *)

(** The [do_depelim] higher-order tactic takes an elimination tactic as argument and an hypothesis 
   and starts a dependent elimination using this tactic. *)

Ltac is_introduced H :=
  match goal with
    | [ H' : _ |- _ ] => match H' with H => idtac end
  end.

Tactic Notation "intro_block" hyp(H) :=
  (is_introduced H ; block_goal ; revert_until H ; block_goal) ||
    (let H' := fresh H in intros until H' ; block_goal) || (intros ; block_goal).

Tactic Notation "intro_block_id" ident(H) :=
  (is_introduced H ; block_goal ; revert_until H ; block_goal) ||
    (let H' := fresh H in intros until H' ; block_goal) || (intros ; block_goal).

Ltac unblock_dep_elim :=
  match goal with
    | |- block ?T => 
      match T with context [ block _ ] => 
        unfold block at 1 ; intros ; unblock_goal
      end
    | _ => unblock_goal
  end.

Ltac simpl_dep_elim := simplify_dep_elim ; simplify_IH_hyps ; unblock_dep_elim.

Ltac do_intros H :=
  (try intros until H) ; (intro_block_id H || intro_block H) ;
  (try simpl in H ; simplify_equations_in H).

Ltac do_depelim_nosimpl tac H := do_intros H ; generalize_by_eqs H ; tac H.

Ltac do_depelim tac H := do_depelim_nosimpl tac H ; simpl_dep_elim.

Ltac do_depind tac H := 
  (try intros until H) ; intro_block H ; (try simpl in H ; simplify_equations_in H) ;
  generalize_by_eqs_vars H ; tac H ; simplify_dep_elim ; simplify_IH_hyps ; 
  unblock_dep_elim.

(** To dependent elimination on some hyp. *)

Ltac depelim id := do_depelim ltac:(fun hyp => do_case hyp) id.

Ltac depelim_term c :=
  let H := fresh "term" in
    set (H:=c) in *; clearbody H ; depelim H.

(** Used internally. *)

Ltac depelim_nosimpl id := do_depelim_nosimpl ltac:(fun hyp => do_case hyp) id.

(** To dependent induction on some hyp. *)

Ltac depind id := do_depind ltac:(fun hyp => do_ind hyp) id.

(** A variant where generalized variables should be given by the user. *)

Ltac do_depelim' tac H :=
  (try intros until H) ; block_goal ; generalize_by_eqs H ; tac H ; simplify_dep_elim ; 
    simplify_IH_hyps ; unblock_goal.

(** Calls [destruct] on the generalized hypothesis, results should be similar to inversion.
   By default, we don't try to generalize the hyp by its variable indices.  *)

Tactic Notation "dependent" "destruction" ident(H) := 
  do_depelim' ltac:(fun hyp => do_case hyp) H.

Tactic Notation "dependent" "destruction" ident(H) "using" constr(c) := 
  do_depelim' ltac:(fun hyp => destruct hyp using c) H.

(** This tactic also generalizes the goal by the given variables before the elimination. *)

Tactic Notation "dependent" "destruction" ident(H) "generalizing" ne_hyp_list(l) := 
  do_depelim' ltac:(fun hyp => revert l ; do_case hyp) H.

Tactic Notation "dependent" "destruction" ident(H) "generalizing" ne_hyp_list(l) "using" constr(c) := 
  do_depelim' ltac:(fun hyp => revert l ; destruct hyp using c) H.

(** Then we have wrappers for usual calls to induction. One can customize the induction tactic by 
   writting another wrapper calling do_depelim. We suppose the hyp has to be generalized before
   calling [induction]. *)

Tactic Notation "dependent" "induction" ident(H) :=
  do_depind ltac:(fun hyp => do_ind hyp) H.

Tactic Notation "dependent" "induction" ident(H) "using" constr(c) :=
  do_depind ltac:(fun hyp => induction hyp using c) H.

(** This tactic also generalizes the goal by the given variables before the induction. *)

Tactic Notation "dependent" "induction" ident(H) "generalizing" ne_hyp_list(l) := 
  do_depelim' ltac:(fun hyp => generalize l ; clear l ; do_ind hyp) H.

Tactic Notation "dependent" "induction" ident(H) "generalizing" ne_hyp_list(l) "using" constr(c) := 
  do_depelim' ltac:(fun hyp => generalize l ; clear l ; induction hyp using c) H.

(** For treating impossible cases. Equations corresponding to impossible
   calls form instances of [ImpossibleCall (f args)]. *)

Class ImpossibleCall {A : Type} (a : A) : Type :=
  is_impossible_call : False.

(** We have a trivial elimination operator for impossible calls. *)

Definition elim_impossible_call {A} (a : A) {imp : ImpossibleCall a} (P : A -> Type) : P a :=
  match is_impossible_call with end.

(** The tactic tries to find a call of [f] and eliminate it. *)

Ltac impossible_call f := on_call f ltac:(fun t => apply (elim_impossible_call t)).

(** [solve_equation] is used to prove the equation lemmas for an existing definition.  *)

Ltac find_empty := simpl in * ;
  match goal with
    | [ H : _ |- _ ] => solve [ clear_except H ; depelim H | specialize_eqs H ; assumption ]
    | [ H : _ <> _ |- _ ] => solve [ red in H ; specialize_eqs H ; assumption ]
  end.

Ltac make_simplify_goal :=
  match goal with 
    [ |- @eq ?A ?T ?U ] => let eqP := fresh "eqP" in 
      set (eqP := fun x : A => x = U) ; change (eqP T)
  end.

Ltac hnf_gl :=
  match goal with 
    [ |- ?P ?T ] => let T' := eval hnf in T in
      convert_concl_no_check (P T')
  end.

Ltac hnf_eq :=
  match goal with
    |- ?x = ?y =>
      let x' := eval hnf in x in
      let y' := eval hnf in y in
        convert_concl_no_check (x' = y')
  end.

Ltac simpl_equations :=
  repeat (hnf_eq ; unfold_equations; rewrite_refl_id).

Ltac simpl_equation_impl :=
  repeat (unfold_equations; rewrite_refl_id).

Ltac simplify_equation := 
  make_simplify_goal ; repeat (hnf_gl ; simpl; unfold_equations; rewrite_refl_id).

Ltac solve_equation f := 
  intros ; try simplify_equation ; try
    (match goal with 
       | [ |- ImpossibleCall _ ] => elimtype False ; find_empty 
       | _ => reflexivity || discriminates
     end).
