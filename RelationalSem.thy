theory RelationalSem

imports Main "./ContractSem"

begin

inductive account_state_natural_change :: "account_state \<Rightarrow> account_state \<Rightarrow> bool"
where
natural:
"account_address old = account_address new \<Longrightarrow>
 account_storage old = account_storage new \<Longrightarrow>
 account_code old = account_code new \<Longrightarrow>
 account_balance old \<le> account_balance new \<Longrightarrow>
 account_ongoing_calls old = account_ongoing_calls new \<Longrightarrow>
 account_state_natural_change old new"

inductive world_turn :: "(account_state * instruction_result) \<Rightarrow> (account_state * variable_env) \<Rightarrow> bool"
where
  world_continue: "world_turn (orig, (InstructionContinue (v, _))) (orig, v)"
| world_call:
  "account_state_natural_change old_state new_state \<Longrightarrow>
   build_venv_called old_state callargs next_venv \<Longrightarrow>
   \<not> (instruction_result_continuing old_result) \<Longrightarrow>
   world_turn (old_state, old_result) (next_state, next_venv)"
| world_return:
  "account_state_natural_change account_state_going_out account_state_back \<Longrightarrow>
   build_venv_returned account_state_back result new_v \<Longrightarrow>
   world_turn (account_state_going_out, (InstructionToWorld (_, _, _, Some _))) (account_state_back, new_v)"
| world_fail:
  "account_state_natural_change account_state_going_out account_state_back \<Longrightarrow>
   build_venv_failed account_state_back = Some new_v \<Longrightarrow>
   world_turn (account_state_going_out, (InstructionToWorld (_, _, _, Some _))) (account_state_back, new_v)"

abbreviation next_instruction :: "variable_env \<Rightarrow> inst \<Rightarrow> bool"
where
"next_instruction v i ==
  (case venv_prg_sfx v of
      i' # _ \<Rightarrow> i = i'
    | _ \<Rightarrow> False)"

inductive contract_turn :: "(account_state * variable_env) \<Rightarrow> (account_state * instruction_result) \<Rightarrow> bool"
where
  contract_to_continue:
  "build_cenv old_account = cenv \<Longrightarrow>
   next_instruction old_venv i \<Longrightarrow>
   instruction_sem old_venv cenv i = InstructionContinue (continuing_v, n) \<Longrightarrow>
   contract_turn (old_account, old_venv) (old_account, InstructionContinue (continuing_v, n))"
| contract_to_world:
  "build_cenv old_account = cenv \<Longrightarrow>
   next_instruction old_venv i \<Longrightarrow>
   instruction_sem old_venv cenv i = InstructionToWorld (act, opt_v, st, bal) \<Longrightarrow>
   account_state_going_out = update_account_state a act opt_v st bal \<Longrightarrow>
   contract_turn (old_account, old_venv) (account_state_going_out, InstructionToWorld (act, opt_v, st, bal))"

inductive one_step :: "(account_state * instruction_result) \<Rightarrow> (account_state * instruction_result) \<Rightarrow> bool"
where
step:
"world_turn a b \<Longrightarrow> contract_turn b c \<Longrightarrow> one_step a c"

inductive initial_instruction_result :: "account_state \<Rightarrow> instruction_result \<Rightarrow> bool"
where
"bal (account_address a) = account_balance a \<Longrightarrow>
 initial_instruction_result a (InstructionToWorld (ContractFail, account_storage a, bal, None))"

(* taken from the book Concrete Semantics *)
inductive star :: "('a \<Rightarrow> 'a \<Rightarrow> bool) \<Rightarrow> 'a \<Rightarrow> 'a \<Rightarrow> bool"
where
refl: "star r x x" |
step: "star r x y \<Longrightarrow> r y z \<Longrightarrow> star r x z"

inductive reachable :: "account_state \<Rightarrow> (account_state * instruction_result) \<Rightarrow> bool"
where
"initial_instruction_result original init \<Longrightarrow>
 star one_step (original, init) fin \<Longrightarrow>
 reachable original fin"

definition no_assertion_failure :: "account_state \<Rightarrow> bool"
where
"no_assertion_failure a ==
  \<forall> fin r. reachable a (fin, r) \<longrightarrow>
  r \<noteq> InstructionAnnotationFailure"

end