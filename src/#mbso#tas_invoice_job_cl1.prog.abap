*&---------------------------------------------------------------------*
*& Include /MBSO/TAS_INVOICE_JOB_CL1
*& Klassenimplementierungen
*&---------------------------------------------------------------------*

CLASS lcl_controller IMPLEMENTATION.

  METHOD run.
    DATA(candidates) = get_billing_candidates( ).

    IF candidates IS INITIAL.
      MESSAGE TEXT-m01 TYPE 'S'.
      RETURN.
    ENDIF.

    IF simulate = abap_false.
      create_billing_docs( CHANGING billing_items = candidates ).
    ENDIF.

    display_alv( candidates ).
  ENDMETHOD.


  METHOD get_billing_candidates.
    "--------------------------------------------------------------------
    " Schritt 1: Streckenauftragspositionen (PSTYV = 'TAS') lesen.
    "            Nur Positionen ohne Ablehnungsgrund (ABGRU = ' ').
    "--------------------------------------------------------------------
    SELECT vbak~vbeln, vbak~kunnr, vbak~waerk,
           vbap~posnr, vbap~matnr, vbap~kwmeng, vbap~vrkme, vbap~netpr
      FROM vbak INNER JOIN vbap ON vbap~vbeln = vbak~vbeln
      WHERE vbak~vkorg IN @so_vkorg
        AND vbak~audat IN @so_date
        AND vbap~pstyv = 'TAS'
        AND vbap~abgru = ' '
      INTO TABLE @DATA(orders).

    CHECK orders IS NOT INITIAL.

    "--------------------------------------------------------------------
    " Schritt 2: Fakturastatus aus VBUP prüfen.
    "            FKSTA: A = nicht fakturiert, B = teilweise fakturiert.
    "            Vollständig fakturierte Positionen (C) werden ausgeblendet.
    "--------------------------------------------------------------------
    SELECT vbeln, posnr, fksta
      FROM vbup
      FOR ALL ENTRIES IN @orders
      WHERE vbeln = @orders-vbeln
        AND posnr = @orders-posnr
        AND ( fksaa = 'A' OR fksaa = 'B' )
      INTO TABLE @DATA(fksta_tab).

    CHECK fksta_tab IS NOT INITIAL.

    " Auftragspositionen auf fakturierfähige einschränken.
    " line_exists() im FOR...WHERE nicht unterstützt → LOOP + CHECK.
    DATA open_items TYPE ty_billing_items.
    LOOP AT orders ASSIGNING FIELD-SYMBOL(<order>).
      CHECK line_exists( fksta_tab[ vbeln = <order>-vbeln
                                    posnr = <order>-posnr ] ).
      APPEND VALUE ty_billing_item(
        sales_order    = <order>-vbeln
        item           = <order>-posnr
        material       = <order>-matnr
        quantity       = <order>-kwmeng
        unit           = <order>-vrkme
        net_price      = <order>-netpr
        currency       = <order>-waerk
        customer       = <order>-kunnr
        billing_status = VALUE #(
          fksta_tab[ vbeln = <order>-vbeln
                     posnr = <order>-posnr ]-fksta OPTIONAL )
      ) TO open_items.
    ENDLOOP.

    CHECK open_items IS NOT INITIAL.

    "--------------------------------------------------------------------
    " Schritt 3: Streckenbestellungen (BSART ZSB) über EKKN ermitteln.
    "            EKKN.VBELN/VBELP enthält die Kontierung auf den
    "            Kundenauftrag. EKKO-Join beschränkt auf BSART = 'ZSB'.
    "--------------------------------------------------------------------
    SELECT ekkn~ebeln, ekkn~ebelp,
           ekkn~vbeln AS sales_order,
           ekkn~vbelp AS item
      FROM ekkn INNER JOIN ekko ON ekko~ebeln = ekkn~ebeln
      FOR ALL ENTRIES IN @open_items
      WHERE ekkn~vbeln = @open_items-sales_order
        AND ekkn~vbelp = @open_items-item
        AND ekko~bsart = 'ZSB'
      INTO TABLE @DATA(po_links).

    CHECK po_links IS NOT INITIAL.

    "--------------------------------------------------------------------
    " Schritt 4: Wareneingänge (BEWTP = 'E') zur Streckenbestellung lesen.
    "            Sortierung nach BUDAT DESCENDING: erster Treffer per
    "            READ TABLE liefert den jüngsten Wareneingang.
    "--------------------------------------------------------------------
    SELECT ebeln, ebelp, budat
      FROM ekbe
      FOR ALL ENTRIES IN @po_links
      WHERE ebeln = @po_links-ebeln
        AND ebelp = @po_links-ebelp
        AND bewtp = 'E'
        AND menge > 0
      INTO TABLE @DATA(goods_receipts).

    CHECK goods_receipts IS NOT INITIAL.

    SORT goods_receipts BY ebeln ebelp budat DESCENDING.

    "--------------------------------------------------------------------
    " Schritt 5: Kundennamen aus KNA1
    "--------------------------------------------------------------------
    DATA customer_keys TYPE TABLE OF vbak-kunnr WITH EMPTY KEY.
    customer_keys = VALUE #( FOR entry IN open_items ( entry-customer ) ).
    SORT customer_keys.
    DELETE ADJACENT DUPLICATES FROM customer_keys.

    SELECT kunnr, name1
      FROM kna1
      FOR ALL ENTRIES IN @customer_keys
      WHERE kunnr = @customer_keys-table_line
      INTO TABLE @DATA(customer_data).

    "--------------------------------------------------------------------
    " Schritt 6: Ergebnisliste aufbauen.
    "            Je offener Auftragsposition werden PO-Link und jüngster
    "            Wareneingang zugeordnet. Positionen ohne WE werden
    "            übersprungen (noch nicht geliefert → nicht fakturierfähig).
    "--------------------------------------------------------------------
    LOOP AT open_items ASSIGNING FIELD-SYMBOL(<item>).

      READ TABLE po_links ASSIGNING FIELD-SYMBOL(<link>)
        WITH KEY sales_order = <item>-sales_order
                 item        = <item>-item.
      CHECK sy-subrc = 0.

      " Jüngster WE durch DESCENDING-Vorsortierung = erster Treffer
      READ TABLE goods_receipts ASSIGNING FIELD-SYMBOL(<gr>)
        WITH KEY ebeln = <link>-ebeln
                 ebelp = <link>-ebelp.
      CHECK sy-subrc = 0.

      <item>-gr_date       = <gr>-budat.
      <item>-po_number     = <link>-ebeln.
      <item>-po_item       = <link>-ebelp.
      <item>-customer_name = VALUE #(
        customer_data[ kunnr = <item>-customer ]-name1 OPTIONAL ).

      APPEND <item> TO result.
    ENDLOOP.

    SORT result BY sales_order item.
  ENDMETHOD.


  METHOD create_billing_docs.
    "--------------------------------------------------------------------
    " Fakturierung per BAPI_BILLINGDOC_CREATEMULTIPLE.
    "
    " Eingabe: eine BAPIVBRK-Zeile je eindeutiger Auftragsnummer.
    " SAP ermittelt intern alle fakturierfähigen Positionen des Auftrags.
    " REF_DOC_CA = 'C' kennzeichnet den Kundenauftrag als Referenzbeleg.
    "
    " Nach erfolgreichem Aufruf: BAPI_TRANSACTION_COMMIT mit WAIT,
    " damit die Belege vor der ALV-Anzeige vollständig gebucht sind.
    " Fehlerauswertung über RETURN (BAPIRET2), Typ 'E' und 'A'.
    "--------------------------------------------------------------------
    DATA billing_input   TYPE TABLE OF bapivbrk        WITH EMPTY KEY.
    DATA billing_success TYPE TABLE OF bapivbrksuccess WITH EMPTY KEY.
    DATA bapi_return     TYPE TABLE OF bapiret2        WITH EMPTY KEY.

    " Duplikatfreie Auftragsliste für den BAPI-Input aufbauen
    LOOP AT billing_items ASSIGNING FIELD-SYMBOL(<item>).
      IF NOT line_exists( billing_input[ ref_doc = <item>-sales_order ] ).
        APPEND VALUE bapivbrk(
          ref_doc    = <item>-sales_order
          ref_doc_ca = 'C'
          bill_date  = sy-datum
        ) TO billing_input.
      ENDIF.
    ENDLOOP.

    CHECK billing_input IS NOT INITIAL.

    CALL FUNCTION 'BAPI_BILLINGDOC_CREATEMULTIPLE'
      TABLES
        billingdatain = billing_input
        success       = billing_success
        return        = bapi_return.

    IF billing_success IS NOT INITIAL.
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
        EXPORTING
          wait = abap_true.
    ELSE.
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    ENDIF.

    " Fehlermeldungen (Typ E/A) aus RETURN-Tabelle als Warnungen ausgeben
    DATA error_count TYPE i.
    LOOP AT bapi_return ASSIGNING FIELD-SYMBOL(<ret>)
      WHERE type = 'E' OR type = 'A'.
      error_count = error_count + 1.
      MESSAGE <ret>-message TYPE 'W'.
    ENDLOOP.

    " Erfolgreich fakturierte Positionen in der Ausgabeliste auf 'C' setzen
    LOOP AT billing_success ASSIGNING FIELD-SYMBOL(<success>).
      DATA(ref_doc) = <success>-ref_doc.
      LOOP AT billing_items ASSIGNING FIELD-SYMBOL(<billing_item>)
        WHERE sales_order = ref_doc.
        <billing_item>-billing_status = 'C'.
      ENDLOOP.
    ENDLOOP.

    DATA(msg_text) = |{ lines( billing_success ) } Fakturabeleg(e) angelegt, { error_count } Fehler.|.
    MESSAGE msg_text TYPE 'S'.
  ENDMETHOD.


  METHOD display_alv.
    " CL_SALV_TABLE=>FACTORY erwartet CHANGING – Arbeitskopie anlegen
    DATA display_items TYPE ty_billing_items.
    display_items = billing_items.

    TRY.
        DATA salv TYPE REF TO cl_salv_table.
        cl_salv_table=>factory(
          IMPORTING r_salv_table = salv
          CHANGING  t_table      = display_items ).

        " --- Listenkopf ---
        DATA(display_settings) = salv->get_display_settings( ).
        display_settings->set_striped_pattern( abap_true ).
        display_settings->set_list_header_size(
          cl_salv_display_settings=>c_header_size_small ).
        display_settings->set_list_header(
          COND #( WHEN simulate = abap_true
                  THEN TEXT-h01
                  ELSE TEXT-h02 ) ).

        " --- Standardfunktionen (Export, Sortierung, Filter) ---
        salv->get_functions( )->set_all( abap_true ).

        " --- Spaltenbreiten und -texte ---
        DATA(columns) = salv->get_columns( ).
        columns->set_optimize( abap_true ).

        DATA(col) = columns->get_column( 'SALES_ORDER' ).
        col->set_long_text( 'Auftragsnummer' ).
        col->set_medium_text( 'Auftrag' ).

        col = columns->get_column( 'ITEM' ).
        col->set_long_text( 'Position' ).
        col->set_medium_text( 'Pos.' ).

        col = columns->get_column( 'MATERIAL' ).
        col->set_long_text( 'Materialnummer' ).
        col->set_medium_text( 'Material' ).

        col = columns->get_column( 'QUANTITY' ).
        col->set_long_text( 'Menge' ).
        col->set_medium_text( 'Menge' ).

        col = columns->get_column( 'UNIT' ).
        col->set_long_text( 'Mengeneinheit' ).
        col->set_medium_text( 'ME' ).
        col->set_short_text( 'ME' ).

        col = columns->get_column( 'NET_PRICE' ).
        col->set_long_text( 'Nettopreis' ).
        col->set_medium_text( 'Preis' ).

        col = columns->get_column( 'CURRENCY' ).
        col->set_long_text( 'Währung' ).
        col->set_medium_text( 'Währ.' ).
        col->set_short_text( 'Währ.' ).

        col = columns->get_column( 'CUSTOMER' ).
        col->set_long_text( 'Auftraggeber (Nr.)' ).
        col->set_medium_text( 'Auftraggeber' ).

        col = columns->get_column( 'CUSTOMER_NAME' ).
        col->set_long_text( 'Name Auftraggeber' ).
        col->set_medium_text( 'Name' ).

        col = columns->get_column( 'GR_DATE' ).
        col->set_long_text( 'Wareneingangsdatum' ).
        col->set_medium_text( 'WE-Datum' ).

        col = columns->get_column( 'PO_NUMBER' ).
        col->set_long_text( 'Streckenbestellung' ).
        col->set_medium_text( 'Bestellung' ).

        col = columns->get_column( 'PO_ITEM' ).
        col->set_long_text( 'Bestellposition' ).
        col->set_medium_text( 'Best.Pos.' ).

        col = columns->get_column( 'BILLING_STATUS' ).
        col->set_long_text( 'Fakturastatus' ).
        col->set_medium_text( 'Fakt.Stat.' ).
        col->set_short_text( 'FS' ).

        " --- Sortierung ---
        DATA(sorts) = salv->get_sorts( ).
        sorts->add_sort( columnname = 'SALES_ORDER' ).
        sorts->add_sort( columnname = 'ITEM' ).

        " --- Summenzeilen für Menge und Preis ---
        DATA(aggregations) = salv->get_aggregations( ).
        aggregations->add_aggregation(
          columnname  = 'QUANTITY'
          aggregation = if_salv_c_aggregation=>total ).
        aggregations->add_aggregation(
          columnname  = 'NET_PRICE'
          aggregation = if_salv_c_aggregation=>total ).

        salv->display( ).

      CATCH cx_salv_msg cx_salv_not_found
            cx_salv_data_error cx_salv_existing INTO DATA(error).
        MESSAGE error->get_text( ) TYPE 'E'.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
