class ZCL_IM_IM_BUPA_CHECKS definition
  public
  final
  create public .

public section.

  interfaces IF_EX_BUPA_FURTHER_CHECKS .
protected section.
private section.
ENDCLASS.



CLASS ZCL_IM_IM_BUPA_CHECKS IMPLEMENTATION.


  method IF_EX_BUPA_FURTHER_CHECKS~CHECK_CENTRAL.
    " Extension point — empty by default. Sites that need to layer
    " additional checks on top of the BP central-check flow can copy
    " this BAdI implementation into a Z-namespace class and add custom
    " logic without touching the address/bank validate paths.
  endmethod.
ENDCLASS.
