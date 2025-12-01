json.array! @page.records, partial: "cards/card", as: :card

json.next_page_url cards_path(@board, page: @page.next_param) unless @page.last?
