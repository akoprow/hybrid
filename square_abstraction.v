Require abstraction.
Require square_flow_conditions.
Require Import util.
Require Import list_util.
Require Import c_util.
Require Import geometry.
Require Import monotonic_flow.
Require concrete.
Require Import List.
Require EquivDec.
Set Implicit Arguments.

Open Scope CR_scope.

Section contents.

  Inductive Reset :=
    | Reset_id
    | Reset_const (c: CR)
    | Reset_map (m: sigT increasing).
  (* we distinguish between const and map because
  for a const reset function with value c, a range with an infinite
  bound [a, inf) should be mapped to [c, c], not to [c, inf).
  we distinguish between id and map because it lets us
  avoid senseless discrete transitions between adjacent regions. *)

  Definition apply_Reset (r: Reset) (v: CR): CR :=
    match r with
    | Reset_id => v
    | Reset_const c => c
    | Reset_map m => proj1_sigT _ _ m v
    end.

  Context
    {Xinterval Yinterval Location: Set}
    {Location_eq_dec: EquivDec.EqDec Location eq}
    {Xinterval_eq_dec: EquivDec.EqDec Xinterval eq}
    {Yinterval_eq_dec: EquivDec.EqDec Yinterval eq}
    {locations: ExhaustiveList Location}
    {Xintervals: ExhaustiveList Xinterval}
    {Yintervals: ExhaustiveList Yinterval}.

  Definition SquareInterval: Set := (Xinterval * Yinterval)%type.

  Variables
    (NoDup_Xintervals: NoDup Xintervals)
    (NoDup_Yintervals: NoDup Yintervals).

  Lemma NoDup_squareIntervals: NoDup (@ExhaustivePairList Xinterval Yinterval _ _).
  Proof with auto.
    unfold exhaustive_list.
    simpl.
    apply NoDup_flat_map; intros...
      destruct (fst (in_map_iff (pair a) Yintervals x) H1).
      destruct (fst (in_map_iff (pair b) Yintervals x) H2).
      destruct H3. destruct H4.
      subst. inversion H4...
    apply NoDup_map...
    intros. inversion H2...
  Qed.

  Variables
    (Xinterval_range: Xinterval -> OpenRange)
    (Yinterval_range: Yinterval -> OpenRange).

  Definition square: SquareInterval -> OpenSquare :=
    prod_map Xinterval_range Yinterval_range.

  Definition in_region (p: Point) (s: SquareInterval): Prop :=
    in_osquare p (square s).

  Lemma in_region_wd x x': x [=] x' -> forall r, in_region x r -> in_region x' r.
  Proof with auto.
    unfold in_region.
    intros.
    destruct H0.
    destruct r.
    simpl in H0, H1. unfold square. simpl.
    destruct x. destruct x'.
    simpl in H0, H1.
    inversion_clear H.
    split; simpl.
      apply (@in_orange_wd (Xinterval_range x0) (Xinterval_range x0)) with s; try reflexivity...
    apply (@in_orange_wd (Yinterval_range y) (Yinterval_range y)) with s0; try reflexivity...
  Qed.

  Variables
    (xflow yflow: Location -> Flow CRasCSetoid)
    (xflow_invr yflow_invr: Location -> OpenRange -> OpenRange -> OpenRange)
    (xflow_invr_correct: forall l, range_flow_inv_spec (xflow l) (xflow_invr l))
    (yflow_invr_correct: forall l, range_flow_inv_spec (yflow l) (yflow_invr l)).

  Let Point := ProdCSetoid CRasCSetoid CRasCSetoid.

  Variables
    (concrete_initial: Location * Point -> Prop)
    (concrete_invariant: Location * Point -> Prop)
    (concrete_invariant_initial: forall p: Location * geometry.Point,
      concrete_initial p -> concrete_invariant p)
    (concrete_guard: Location * geometry.Point -> Location -> Prop)
    (reset: Location -> Location -> Point -> Point).

  Hypothesis invariant_wd: forall l l', l = l' -> forall p p', p[=]p' ->
    (concrete_invariant (l, p) <-> concrete_invariant (l', p')).

  Hypothesis NoDup_locations: NoDup locations.

  Variables
    (absXinterval: CR -> Xinterval)
    (absYinterval: CR -> Yinterval).

  Variable initial: Location -> Xinterval -> Yinterval -> bool.

  Definition abstract_guard (l: Location) (s: SquareInterval) (l': Location): Prop
    := exists p, geometry.in_osquare p (square s) /\
	concrete_guard (l, p) l'.

  Definition abstract_invariant (ls: Location * SquareInterval): Prop :=
    exists p,
      geometry.in_osquare p (square (snd ls)) /\
      concrete_invariant (fst ls, p).

  (* If one's invariants can be expressed as a single square for each
   location, we can decide it for the abstract system by computing
   overlap with regions: *)

  Hypothesis invariant_squares: Location -> OpenSquare.
  Hypothesis invariant_squares_correct: forall l p,
    concrete_invariant (l, p) -> in_osquare p (invariant_squares l).

Ltac bool_contradict id :=
  match goal with
  | id: ?X = false |- _ =>
      absurd (X = true); [congruence | idtac]
  | id: ?X = true |- _ =>
      absurd (X = false); [congruence | idtac]
  end.

  Obligation Tactic := idtac.
  Program Definition invariant_dec eps (li : Location * SquareInterval): overestimation (abstract_invariant li) :=
    osquares_overlap_dec eps (invariant_squares (fst li)) (square (snd li)).
  Next Obligation. Proof with auto.
    intros eps li H [p [B C]].
    apply (overestimation_false _ H), osquares_share_point with p...
  Qed.

  Variable invariant_decider: forall s, overestimation (abstract_invariant s).

  Variables (reset_x reset_y: Location -> Location -> Reset).

  Hypothesis reset_components: forall p l l',
    reset l l' p = (apply_Reset (reset_x l l') (fst p), apply_Reset (reset_y l l') (snd p)).

  Variables
    (absXinterval_correct: forall p l, concrete_invariant (l, p) ->
      in_orange (Xinterval_range (absXinterval (fst p))) (fst p))
    (absYinterval_correct: forall p l, concrete_invariant (l, p) ->
      in_orange (Yinterval_range (absYinterval (snd p))) (snd p))
    (absXinterval_wd: forall x x', x == x' -> absXinterval x = absXinterval x')
    (absYinterval_wd: forall y y', y == y' -> absYinterval y = absYinterval y').

  Instance SquareInterval_eq_dec: EquivDec.EqDec SquareInterval eq.
    repeat intro.
    cut (decision (x = y)). auto.
    dec_eq. apply Yinterval_eq_dec. apply Xinterval_eq_dec.
  Defined.

  Definition concrete_system: concrete.System :=
    @concrete.Build_System Point Location Location_eq_dec
      locations NoDup_locations concrete_initial
      concrete_invariant concrete_invariant_initial invariant_wd
      (fun l: Location => product_flow (xflow l) (yflow l))
      concrete_guard reset.

  Program Definition select_region (l: concrete.Location concrete_system)
    (p: concrete.Point concrete_system) (I: concrete.invariant (l, p)): sig (in_region p) :=
      (absXinterval (fst p), absYinterval (snd p)).
  Next Obligation.
    split; simpl; eauto using absXinterval_correct, absYinterval_correct.
  Qed.

  Definition ap: abstract.Parameters concrete_system :=
    abstract.Build_Parameters concrete_system _ _
      NoDup_squareIntervals in_region in_region_wd select_region.

  Section initial_dec.

    Variables (initial_location: Location) (initial_square: OpenSquare)
      (initial_representative:
        forall (s : concrete.State concrete_system),
          let (l, p) := s in
            concrete.initial s ->
            l = initial_location /\ in_osquare p initial_square).

    Obligation Tactic := idtac.

    Program Definition initial_dec (eps: Qpos) s: overestimation
      (abstract.Initial ap s) :=
        (overestimate_conj (osquares_overlap_dec eps (initial_square) (square (snd s)))
          (weaken_decision (Location_eq_dec (fst s) initial_location))).
    Next Obligation. Proof with auto.
      intros eps [l i].
      destruct_call overestimate_conj.
      simpl.
      intros H [[a b] [H0 H1]].
      apply n...
      destruct (initial_representative (l, (a, b)) H1).
      split...
      apply osquares_share_point with (a, b)...
    Qed.

  End initial_dec.

  Section guard_dec.

    Variable guard_square: Location -> Location -> option OpenSquare.

    Hypothesis guard_squares_correct: forall s l',
      concrete.guard concrete_system s l' <->
      match guard_square (fst s) l' with
      | None => False
      | Some v => in_osquare (snd s) v
      end.

    Obligation Tactic := idtac.

    Program Definition guard_dec eps l r l':
      overestimation (abstract_guard  l r l') :=
        match guard_square l l' with
        | Some s => osquares_overlap_dec eps s (square r)
        | None => false
        end.

    Next Obligation. Proof with auto.
      intros eps l r l' fv s e.
      intro.
      intro.
      apply (overestimation_false _ H).
      unfold abstract_guard in H0.
      destruct H0.
      destruct H0.
      apply osquares_share_point with x...
      pose proof (fst (guard_squares_correct _ _) H1).
      subst fv.
      simpl in H2.
      rewrite <- e in H2.
      assumption.
    Qed.

    Next Obligation.
      intros eps l r l' fv s e.
      subst.
      simpl in s.
      intros [p [B C]].
      pose proof (fst (guard_squares_correct _ _) C). clear C.
      simpl in B, H.
      rewrite <- s in H.
      assumption.
    Qed.

  End guard_dec.

  Variable guard_decider: forall l s l', overestimation (abstract_guard l s l').

  Definition map_orange' (f: sigT increasing): OpenRange -> OpenRange
    := let (_, y) := f in map_orange y.

  Let State := prod Location SquareInterval.

  Definition disc_trans_regions (eps: Qpos) (l l': Location) (r: SquareInterval): list SquareInterval
    :=
    if guard_decider l r l' && invariant_decider (l, r) then
    let xs := match reset_x l l' with
      | Reset_const c => filter (fun r' => oranges_overlap_dec eps
        (unit_range c: OpenRange) (Xinterval_range r')) Xintervals
      | Reset_map f => filter (fun r' => oranges_overlap_dec eps
        (map_orange' f (Xinterval_range (fst r))) (Xinterval_range r')) Xintervals
      | Reset_id => [fst r] (* x reset is id, so we can only remain in this x range *)
      end in
    let ys := match reset_y l l' with
      | Reset_const c => filter (fun r' => oranges_overlap_dec eps
        (unit_range c: OpenRange) (Yinterval_range r')) Yintervals
      | Reset_map f => filter (fun r' => oranges_overlap_dec eps
        (map_orange' f (Yinterval_range (snd r))) (Yinterval_range r')) Yintervals
      | Reset_id => [snd r] (* x reset is id, so we can only remain in this x range *)
      end
     in flat_map (fun x => filter (fun s => invariant_decider (l', s)) (map (pair x) ys)) xs
   else [].

  Definition raw_disc_trans (eps: Qpos) (s: State): list State :=
    let (l, r) := s in
    flat_map (fun l' => map (pair l') (disc_trans_regions eps l l' r)) locations.

  Lemma NoDup_disc_trans eps s: NoDup (raw_disc_trans eps s).
  Proof with auto.
    intros.
    unfold raw_disc_trans.
    destruct s.
    apply NoDup_flat_map...
      intros.
      destruct (fst (in_map_iff _ _ _) H1).
      destruct (fst (in_map_iff _ _ _) H2).
      destruct H3. destruct H4.
      subst.
      inversion_clear H4...
    intros.
    apply NoDup_map.
      intros.
      inversion_clear H2...
    unfold disc_trans_regions.
    destruct (guard_decider l s x && invariant_decider (l, s))...
    apply NoDup_flat_map...
        intros.
        destruct (fst (filter_In _ _ _) H2).
        destruct (fst (filter_In _ _ _) H3).
        destruct (fst (in_map_iff _ _ _) H4).
        destruct (fst (in_map_iff _ _ _) H6).
        destruct H8. destruct H9.
        subst x0. inversion_clear H9...
      intros.
      apply NoDup_filter.
      apply NoDup_map.
        intros.
        inversion_clear H3...
      destruct (reset_y l x)...
    destruct (reset_x l x)...
  Qed.

  Hint Resolve absXinterval_correct absYinterval_correct.
  Hint Resolve in_map_orange.

  Lemma respects_disc (eps: Qpos) (s1 s2 : concrete.State concrete_system):
    let (l1, p1) := s1 in
    let (l2, p2) := s2 in
    concrete.disc_trans s1 s2 -> forall i1, in_region p1 i1 ->
    exists i2, in_region p2 i2 /\
    In (l2, i2) (raw_disc_trans eps (l1, i1)).
  Proof with simpl; auto.
    destruct s1. destruct s2.
    intros.
    unfold concrete.Point, concrete_system in s, s0.
    unfold concrete.Location, concrete_system in l, l0.
    unfold concrete.disc_trans in H.
    destruct H. destruct H0. destruct H1. destruct H3.
    simpl in H1.
    subst s0.
    simpl @fst in H.
    unfold raw_disc_trans.
    cut (exists i2: SquareInterval, in_region (reset l l0 s) i2 /\
         In i2 (disc_trans_regions eps l l0 i1)).
      intro.
      destruct H1.
      exists x.
      destruct H1.
      split...
      apply <- in_flat_map.
      exists l0...
    rewrite reset_components.
    set (xi := match reset_x l l0 with
      | Reset_id => fst i1
      | Reset_const c => absXinterval c
      | Reset_map f => absXinterval (proj1_sigT _ _ f (fst s))
      end).
    set (yi := match reset_y l l0 with
      | Reset_id => snd i1
      | Reset_const c => absYinterval c
      | Reset_map f => absYinterval (proj1_sigT _ _ f (snd s))
      end).
    exists (xi, yi).
    rewrite reset_components in H4.
    split.
      split; simpl.
        subst xi. clear yi.
        destruct (reset_x l l0); auto; apply (absXinterval_correct H4).
      subst yi. clear xi.
      destruct (reset_y l l0); auto; apply (absYinterval_correct H4).
    unfold disc_trans_regions.
    destruct (guard_decider l i1 l0).
    simpl overestimation_bool at 1.
    destruct x.
      destruct (invariant_decider (l, i1)).
      simpl overestimation_bool at 1.
      destruct x.
        simpl andb.
        cbv iota.
        apply <- in_flat_map.
        exists xi.
        split.
          clear yi.
          subst xi.
          destruct (reset_x l l0); auto.
            apply in_filter; auto.
            apply not_false_is_true.
            destruct_call oranges_overlap_dec...
            intro. apply n1...
            apply oranges_share_point with c...
              simpl. split...
            apply (absXinterval_correct H4).
          simpl in H4.
          apply in_filter; auto.
          apply not_false_is_true.
          destruct_call oranges_overlap_dec...
          intro. apply n1...
          apply oranges_share_point with (proj1_sigT _ _ m (fst s))...
            unfold map_orange'.
            destruct m.
            apply in_map_orange...
          apply (absXinterval_correct H4).
        apply in_filter.
          apply in_map.
          subst yi.
          destruct (reset_y l l0); auto.
            apply in_filter; auto.
            apply not_false_is_true.
            destruct_call oranges_overlap_dec...
            intro. apply n1...
            apply oranges_share_point with c...
              simpl. split...
            apply (absYinterval_correct H4).
          simpl in H4.
          apply in_filter; auto.
          apply not_false_is_true.
          destruct_call oranges_overlap_dec...
          intro. apply n1...
          apply oranges_share_point with (proj1_sigT _ _ m (snd s))...
            unfold map_orange'.
            destruct m.
            apply in_map_orange...
          apply (absYinterval_correct H4).
        apply not_false_is_true.
        intro.
        apply (overestimation_false _ H1).
        unfold abstract_invariant.
        simpl.
        exists (apply_Reset (reset_x l l0) (fst s), apply_Reset (reset_y l l0) (snd s)).
        split...
        split; simpl.
          subst xi.
          destruct (reset_x l l0); auto; apply (absXinterval_correct H4).
        subst yi.
        destruct (reset_y l l0); auto; apply (absYinterval_correct H4).
      simpl.
      apply n0...
      unfold abstract_invariant.
      simpl. exists s... split... split...
    simpl.
    apply n...
    unfold abstract_guard.
    simpl. exists s... split... split...
  Qed.

  Program Definition disc_trans (eps: Qpos) (s: State):
    sig (fun l: list State => LazyProp (NoDup l /\ abstract.DiscRespect ap s l))
    := raw_disc_trans eps s.
  Next Obligation. Proof with auto.
    split.
      apply NoDup_disc_trans.
    repeat intro.
    set (respects_disc eps (fst s, p1) s2).
    simpl in y.
    destruct s2.
    destruct (y H0 _ H1).
    destruct H2.
    destruct s.
    eauto.
  Qed.

  Program Definition cont_trans_cond_dec eps l r r':
    overestimation (abstraction.cont_trans_cond ap l r r') :=
      square_flow_conditions.decide_practical
        (xflow_invr l) (yflow_invr l) (square r) (square r') eps &&
      invariant_dec eps (l, r) &&
      invariant_dec eps (l, r').

  Next Obligation. Proof with auto.
    intros eps l i1 i2 cond.
    intros [p [q [pi [qi [H2 [[t tn] [ctc cteq]]]]]]].
    simpl in ctc. simpl @snd in cteq. simpl @fst in cteq.
    clear H2.
    destruct (andb_false_elim _ _ cond); clear cond.
      destruct (andb_false_elim _ _ e); clear e.
        apply (overestimation_false _ e0). clear e0.
        apply square_flow_conditions.ideal_implies_practical_decideable with (xflow l) (yflow l)...
            intros. apply xflow_invr_correct with x...
          intros. apply yflow_invr_correct with y...
        exists p. split...
        exists t. split. 
          apply (CRnonNeg_le_zero t)...
        simpl bsm in cteq. 
        destruct p. destruct q. inversion cteq.
        destruct pi. destruct qi. simpl in H1, H2, H3, H4.
        split.
          apply in_orange_wd with (Xinterval_range (fst i2)) s1...
          symmetry...
        apply in_orange_wd with (Yinterval_range (snd i2)) s2...
        symmetry...
      apply (overestimation_false _ e0).
      unfold abstract_invariant.
      exists p.
      split...
      apply (concrete.invariant_wd concrete_system (refl_equal l) p
        (concrete.flow concrete_system l p (' 0))).
        symmetry. apply flow_zero.
      simpl. apply ctc... apply (CRnonNeg_le_zero t)...
    apply (overestimation_false _ e).
    exists q.
    split...
    apply (concrete.invariant_wd concrete_system (refl_equal l) _ q cteq).
    simpl. apply ctc... apply (CRnonNeg_le_zero t)...
  Qed.

  (* If one's initial location can be expressed as a simple square
   in a single location, we can decide it for the abstract system
   by checking overlap with regions. *)

End contents.
