*&---------------------------------------------------------------------*
*& Include /MBSO/TAS_INVOICE_JOB_SEL
*& Selektionsbild und Initialisierung
*&---------------------------------------------------------------------*
*  Textsymbole (in SE38 → Springen → Textelemente pflegen):
*    TEXT-001 = 'Streckenaufträge fakturieren'
*    TEXT-h01 = 'SIMULATION – fakturierfähige Streckenaufträge (keine Buchung)'
*    TEXT-h02 = 'Streckenaufträge – Fakturierung durchgeführt'
*    TEXT-m01 = 'Keine fakturierfähigen Streckenaufträge im gewählten Zeitraum'
*----------------------------------------------------------------------

SELECTION-SCREEN BEGIN OF BLOCK criteria WITH FRAME TITLE TEXT-001.
  SELECT-OPTIONS so_vkorg FOR vbak-vkorg OBLIGATORY.
  SELECT-OPTIONS so_date  FOR vbak-audat.
  PARAMETERS     simulate TYPE abap_bool AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK criteria.

INITIALIZATION.
  " Aktuellen Monat als Vorschlagswert für den Datumsbereich setzen
  so_date-sign   = 'I'.
  so_date-option = 'BT'.
  so_date-low    = CONV dats( sy-datum(6) && '01' ).
  so_date-high   = sy-datum.
  APPEND so_date.
