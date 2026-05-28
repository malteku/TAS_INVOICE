*&---------------------------------------------------------------------*
*& Report /MBSO/TAS_INVOICE_JOB
*& Streckenaufträge (TAS) fakturieren
*&---------------------------------------------------------------------*
REPORT /mbso/tas_invoice_job.

INCLUDE /mbso/tas_invoice_job_top.
INCLUDE /mbso/tas_invoice_job_sel.
INCLUDE /mbso/tas_invoice_job_cl1.

START-OF-SELECTION.
  NEW lcl_controller( )->run( ).
