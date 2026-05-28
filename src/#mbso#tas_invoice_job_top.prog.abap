*&---------------------------------------------------------------------*
*& Include /MBSO/TAS_INVOICE_JOB_TOP
*& Globale Typdefinitionen und Klassendefinitionen
*&---------------------------------------------------------------------*

"! Ausgabestruktur für eine fakturierfähige Streckenauftragsposition
TYPES:
  BEGIN OF ty_billing_item,
    sales_order    TYPE vbak-vbeln,
    item           TYPE vbap-posnr,
    material       TYPE vbap-matnr,
    quantity       TYPE vbap-kwmeng,
    unit           TYPE vbap-vrkme,
    net_price      TYPE vbap-netpr,
    currency       TYPE vbak-waerk,
    customer       TYPE vbak-kunnr,
    customer_name  TYPE kna1-name1,
    gr_date        TYPE ekbe-budat,
    gr_quantity    TYPE ekbe-menge,
    po_number      TYPE ekbe-ebeln,
    po_item        TYPE ekbe-ebelp,
    billing_status TYPE vbup-fksta,
  END OF ty_billing_item,

  ty_billing_items TYPE STANDARD TABLE OF ty_billing_item WITH EMPTY KEY.

"! <p class="shorttext synchronized" lang="de">Streckenaufträge fakturieren – Controller</p>
CLASS lcl_controller DEFINITION FINAL.
  PUBLIC SECTION.
    "! Hauptsteuerung: Selektion → optionale Fakturierung → ALV-Ausgabe
    METHODS run.
  PRIVATE SECTION.
    "! Ermittelt alle Streckenauftragspositionen (TAS) mit gebuchtem
    "! Wareneingang zur Streckenbestellung (ZSB) und offenem Fakturastatus
    METHODS get_billing_candidates
      RETURNING VALUE(result) TYPE ty_billing_items.
    "! Legt Fakturabelege per BAPI_BILLINGDOC_CREATEMULTIPLE an.
    "! Markiert erfolgreich fakturierte Positionen in billing_items.
    METHODS create_billing_docs
      CHANGING billing_items TYPE ty_billing_items.
    "! Zeigt das Ergebnis als ALV-Liste (CL_SALV_TABLE) an
    METHODS display_alv
      IMPORTING billing_items TYPE ty_billing_items.
ENDCLASS.
