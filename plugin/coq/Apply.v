Add LoadPath "coq".
Require Import List.
Require Import Ornamental.Ornaments.
Require Import Test.

(*
 * Test applying ornaments to lift functions, without internalizing
 * the ornamentation (so the type won't be useful yet).
 *)

(* --- Simple functions on lists --- *)

Definition hd (A : Type) (default : A) (l : list A) :=
  list_rect
    (fun (_ : list A) => A)
    default
    (fun (x : A) (_ : list A) (_ : A) =>
      x)
    l.

Definition hd_vect (A : Type) (default : A) (n : nat) (v : vector A n) :=
  vector_rect
    A
    (fun (n0 : nat) (_ : vector A n0) => A)
    default
    (fun (n0 : nat) (x : A) (_ : vector A n0) (_ : A) =>
      x)
    n
    v.

Definition hd_vect_packed (A : Type) (default : A) (pv : packed_vector A) :=
  sigT_rect
    (fun _ : packed_vector A => A)
    (fun (n : nat) (v0 : vector A n) =>
      hd_vect A default n v0)
    pv.

Apply ornament orn_list_vector orn_list_vector_inv in hd as hd_vect_auto.
Apply ornament orn_list_vector_inv orn_list_vector in hd_vect_packed as hd_auto.

Theorem test_orn_hd :
  forall (A : Type) (a : A) (pv : packed_vector A),
    hd_vect_auto A a pv = hd_vect_packed A a pv.
Proof.
  intros. induction pv; induction p; auto.
Qed.

Theorem test_orn_hd_proj :
  forall (A : Type) (a : A) (n : nat) (v : vector A n),
    hd_vect_auto A a (existT (vector A) n v) = hd_vect A a n v.
Proof.
  intros. induction v; auto.
Qed.

Theorem test_deorn_hd :
  forall (A : Type) (a : A) (l : list A),
    hd_auto A a l = hd A a l.
Proof.
  intros. induction l; auto.
Qed.

Definition hd_error (A : Type) (l:list A) :=
  list_rect
    (fun (_ : list A) => option A)
    None
    (fun (x : A) (_ : list A) (_ : option A) =>
      Some x)
    l.

Definition hd_vect_error (A : Type) (n : nat) (v : vector A n) :=
  vector_rect
    A
    (fun (n0 : nat) (_ : vector A n0) => option A)
    None
    (fun (n0 : nat) (x : A) (_ : vector A n0) (_ : option A) =>
      Some x)
    n
    v.

Definition hd_vect_error_packed (A : Type) (pv : packed_vector A) :=
  sigT_rect
    (fun _ : packed_vector A => option A)
    (fun (n : nat) (v0 : vector A n) =>
      hd_vect_error A n v0)
    pv.

Print hd_vect_error_packed.

Apply ornament orn_list_vector orn_list_vector_inv in hd_error as hd_vect_error_auto.
Apply ornament orn_list_vector_inv orn_list_vector in hd_vect_error_packed as hd_error_auto.

(*
 * Same situation as above
 *)
Theorem test_orn_hd_error :
  forall (A : Type) (pv : packed_vector A),
    hd_vect_error_auto A pv = hd_vect_error_packed A pv.
Proof.
  intros. induction pv; induction p; auto.
Qed.

Theorem test_orn_hd_error_proj :
  forall (A : Type) (n : nat) (v : vector A n),
    hd_vect_error_auto A (existT (vector A) n v) = hd_vect_error A n v.
Proof.
  intros. induction v; auto.
Qed.

Theorem test_deorn_hd_error :
  forall (A : Type) (a : A) (l : list A),
    hd_error_auto A l = hd_error A l.
Proof.
  intros. induction l; auto.
Qed.

Definition append (A : Type) (l1 : list A) (l2 : list A) :=
  list_rect
    (fun (_ : list A) => list A)
    l2
    (fun (a : A) (_ : list A) (IH : list A) =>
      a :: IH)
    l1.

(* For now, we don't eliminate the vector reference, since incides might refer to other things *)
Definition plus_vect (A : Type) (n1 : nat) (v1 : vector A n1) (n2 : nat) (v2 : vector A n2) :=
  vector_rect
    A
    (fun (n0 : nat) (_ : vector A n0) => nat)
    n2
    (fun (n0 : nat) (a : A) (v0 : vector A n0) (IH : nat) =>
      S (IH))
    n1
    v1.

(*
 * Not used yet.
 *)
Definition plus_vect_exp (A : Type) (pv1 : packed_vector A) (pv2 : packed_vector A) :=
  sigT_rect
    (fun _ : sigT (fun (n : nat) => vector A n) => nat)
    (fun (n0 : nat) (v0 : vector A n0) =>
      vector_rect
        A
        (fun (n0 : nat) (_ : vector A n0) => nat)
        (sigT_rect
          (fun _ : sigT (fun (n : nat) => vector A n) => nat)
          (fun (n2 : nat) (v2 : vector A n2) => n2)
          pv2)
        (fun (n0 : nat) (a : A) (v0 : vector A n0) (IH : nat) =>
          S IH)
       n0
       v0)
   pv1.

Definition append_vect (A : Type) (n1 : nat) (v1 : vector A n1) (n2 : nat) (v2 : vector A n2) :=
  vector_rect
    A
    (fun (n0 : nat) (v0 : vector A n0) => vector A (plus_vect A n0 v0 n2 v2))
    v2
    (fun (n0 : nat) (a : A) (v0 : vector A n0) (IH : vector A (plus_vect A n0 v0 n2 v2)) =>
      consV A (plus_vect A n0 v0 n2 v2) a IH)
    n1
    v1.

(*
 * This version doesn't reference new indexer.
 * Eventually want to be able to get index from this too,
 * and also want to move each of these inner sigT_rect... into projT1 or something
 * similar.
 *)
Definition append_vect_packed (A : Type) (pv1 : packed_vector A) (pv2 : packed_vector A) :=
  sigT_rect
    (fun _ : sigT (fun (n : nat) => vector A n) => sigT (fun (n : nat) => vector A n))
    (fun (n : nat) (v : vector A n) =>
      vector_rect
        A
        (fun (n0 : nat) (v0 : vector A n0) => sigT (fun (n : nat) => vector A n))
        pv2
        (fun (n0 : nat) (a : A) (v0 : vector A n0) (IH : sigT (fun (n : nat) => vector A n)) =>
          existT
            (vector A)
            (S (projT1 IH))
            (consV A (projT1 IH) a (projT2 IH)))
        n
        v)
    pv1.

Print append_vect_packed.

Apply ornament orn_list_vector orn_list_vector_inv in append as append_vect_auto.
Apply ornament orn_list_vector_inv orn_list_vector in append_vect_packed as append_auto.

(*
 * For this one, we can't state the equality, but we can use existsT.
 *)
Theorem eq_S:
  forall n n',
    n = n' ->
    S n = S n'.
Proof.
  intros. subst. auto. 
Qed.

Theorem eq_vect_cons:
  forall A n (v : vector A n) n' (v' : vector A n'), 
    existT (vector A) n v = existT (vector A) n' v' ->
    forall (a : A),
      (existT (vector A) (S n) (consV A n a v)) =
      (existT (vector A) (S n') (consV A n' a v')).
Proof.
  intros. inversion H. subst. auto.
Qed.

Theorem eq_pv_cons:
  forall A (pv : sigT (vector A)) (pv' : sigT (vector A)),
    pv = pv' ->
    forall (a : A),
      (existT 
        (vector A)
        (S (projT1 pv)) 
        (consV A (projT1 pv) a (projT2 pv))) =
      (existT 
        (vector A)
        (S (projT1 pv')) 
        (consV A (projT1 pv') a (projT2 pv'))).
Proof.
  intros. inversion H. subst. auto.
Qed.

Theorem vect_iso:
  forall (A : Type) (pv : packed_vector A),
    pv = orn_list_vector A (orn_list_vector_inv A pv).
Proof.
  intros. induction pv. induction p; try apply eq_vect_cons; auto.
Qed.

Theorem test_plus:
  forall A (pv1 : packed_vector A) (pv2 : packed_vector A),
    (projT1 (append_vect_packed A pv1 pv2) = projT1 (append_vect_auto A pv1 pv2)).
Proof.
  intros. induction pv1; induction pv2; induction p; induction p0; try apply eq_S; auto.
Qed.

Theorem test_orn_append:
  forall A (pv1 : packed_vector A) (pv2 : packed_vector A),
    append_vect_packed A pv1 pv2 = append_vect_auto A pv1 pv2.
Proof.
  intros. induction pv1.
  induction p.
  - unfold append_vect_auto. simpl. apply vect_iso.
  - apply eq_pv_cons with (a := a) in IHp. apply IHp.
Qed.

Theorem test_orn_append_proj :
  forall (A : Type) (n1 : nat) (v1 : vector A n1) (n2 : nat) (v2 : vector A n2),
    existT
      (vector A)
      (projT1 (append_vect_auto A (existT (vector A) n1 v1) (existT (vector A) n2 v2)))
      (projT2 (append_vect_auto A (existT (vector A) n1 v1) (existT (vector A) n2 v2))) =
    existT
      (vector A)
      (plus_vect A n1 v1 n2 v2)
      (append_vect A n1 v1 n2 v2).
Proof.
  intros. induction v1; induction v2; try apply eq_vect_cons; auto.
Qed.

(*
 * To prove the deornamentation case, we need the same lemma,
 * but we can state the equality directly.
 *)
Theorem eq_cons:
  forall A (l : list A) (l' : list A),
    l = l' ->
    forall (a : A), a :: l = a :: l'.
Proof.
  intros. inversion H. subst. auto.
Qed.

Theorem vect_inv_iso:
  forall (A : Type) (l : list A),
    l = orn_list_vector_inv A (orn_list_vector A l).
Proof.
  intros. induction l; try apply eq_cons; auto.
Qed.

(* TODO fix
Theorem test_deorn_append:
  forall A (l : list A) (l' : list A),
    append A l l' = append_auto A l l'.
Proof.
  intros A l. induction l.
  - simpl. unfold append_auto. induction l'.
    + auto.
    + simpl. apply eq_cons. unfold append_vect_packed in IHl'. apply eq_cons. unfold orn_list_vector_inv in IHl'.
*)

(* For now, we don't eliminate the vector reference, since incides might refer to other things *)
Definition pred_vect (A : Type) (n : nat) (v : vector A n) :=
  vector_rect
    A
    (fun (n0 : nat) (_ : vector A n0) => nat)
    0
    (fun (n0 : nat) (a : A) (v0 : vector A n0) (_ : nat) =>
      n0)
    n
    v.

Definition pred_vect_exp (A : Type) (pv : packed_vector A) :=
  sigT_rect
    (fun _ : packed_vector A => nat)
    (fun (n0 : nat) (v0 : vector A n0) =>
      pred_vect A n0 v0)
    pv.

Definition tl (A : Type) (l : list A) :=
  @list_rect
   A
   (fun (l0 : list A) => list A)
   (@nil A)
   (fun (a : A) (l0 : list A) (_ : list A) =>
     l0)
   l.

Definition tl_vect (A : Type) (n : nat) (v : vector A n) :=
  vector_rect
   A
   (fun (n0 : nat) (v0 : vector A n0) => vector A (pred_vect A n0 v0))
   (nilV A)
   (fun (n0 : nat) (a : A) (v0 : vector A n0) (_ : vector A (pred_vect A n0 v0)) =>
     v0)
   n
   v.

(* This version might only work since we don't need the index of the IH *)
(* TODO! Universe inconsistency prevents us from being able to use packed_vector *)
Definition tl_vect_packed (A : Type) (pv : packed_vector A) :=
  sigT_rect
    (fun _ : sigT (fun (n : nat) => vector A n) => sigT (fun (n : nat) => vector A n))
    (fun (n : nat) (v : vector A n) =>
      vector_rect
       A
       (fun (n0 : nat) (v0 : vector A n0) => sigT (fun (n : nat) => vector A n))
       (existT (vector A) 0 (nilV A))
       (fun (n0 : nat) (a : A) (v0 : vector A n0) (_ : sigT (fun (n : nat) => vector A n)) =>
         existT (vector A) n0 v0)
       n
      v)
    pv.

Apply ornament orn_list_vector orn_list_vector_inv in tl as tl_vect_auto.
Apply ornament orn_list_vector_inv orn_list_vector in tl_vect_packed as tl_auto.

Print tl_vect_auto.
Print tl.

(* TODO fix application *)

Theorem coh_vect:
  forall (A : Type) (n : nat) (v : vector A n),
    existT (vector A) (orn_list_vector_index A (orn_list_vector_inv A (existT (vector A) n v))) (projT2 (orn_list_vector A (orn_list_vector_inv A (existT (vector A) n v)))) = 
    existT (vector A) n v.
Proof.
  intros. induction v.
  - reflexivity.
  - apply eq_vect_cons. apply IHv.
Qed.

(*
 * Same situation as above
 *)
Theorem test_orn_tl :
  forall (A : Type) (pv : packed_vector A),
    tl_vect_auto A pv = tl_vect_packed A pv.
Proof.
  intros. induction pv; induction p; try apply coh_vect; auto.
Qed.

Theorem test_orn_tl_proj :
  forall (A : Type) (n : nat) (v : vector A n),
    existT
      (vector A)
      (projT1 (tl_vect_auto A (existT (vector A) n v)))
      (projT2 (tl_vect_auto A (existT (vector A) n v))) =
    existT
      (vector A)
      (pred_vect A n v)
      (tl_vect A n v).
Proof.
  intros. induction v; try apply coh_vect; auto.
Qed.

Theorem coh:
  forall (A : Type) (l : list A),
    orn_list_vector_inv A (existT (vector A) (orn_list_vector_index A l) (projT2 (orn_list_vector A l))) = l.
Proof.
  intros. induction l.
  - reflexivity.
  - apply eq_cons. apply IHl.
Qed.

Print tl_auto.

Theorem test_deorn_tl :
  forall (A : Type) (l : list A),
    tl_auto A l = tl A l.
Proof.
  intros. induction l; try apply coh; auto.
Qed.

(* TODO try In, then you can try the facts about In, which should translate over as soon
   as app translates over. Then try app_nil_r and so on. *)

(* TODO test more to see if there are bugs before internalizing *)

(* TODO test some functions on other types besides lists/vectors *)
