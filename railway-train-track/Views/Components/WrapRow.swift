//
//  WrapRow.swift
//  railway-train-track
//
//  Created by Qiwei Li on 12/8/25.
//

import SwiftUI

struct WrapRow: Layout {
    var maxColumns: Int = 3
    var spacing: CGFloat = 0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        
        var totalHeight: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var itemCountInRow = 0
        
        for (index, subview) in subviews.enumerated() {
            // Determine width for this item based on the row configuration
            // "if only 1 image in a row, it takes full width, 2 images, takes 50% width, 3 images takes 33%."
            
            // Calculate row index and items in this row
            let rowIndex = index / maxColumns
            let itemsInThisRow = min(maxColumns, subviews.count - (rowIndex * maxColumns))
            let itemWidth = width / CGFloat(itemsInThisRow)
            
            let size = subview.sizeThatFits(ProposedViewSize(width: itemWidth, height: nil))
            currentRowHeight = max(currentRowHeight, size.height)
            
            itemCountInRow += 1
            
            if itemCountInRow == maxColumns || index == subviews.count - 1 {
                totalHeight += currentRowHeight
                currentRowHeight = 0
                itemCountInRow = 0
            }
        }
        
        return CGSize(width: width, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = bounds.width
        var yOffset = bounds.minY
        
        // Process by rows to handle the variable width logic easily
        let chunkedIndices = stride(from: 0, to: subviews.count, by: maxColumns)
        
        for startIndex in chunkedIndices {
            let endIndex = min(startIndex + maxColumns, subviews.count)
            let rowIndices = startIndex..<endIndex
            let itemsInThisRow = rowIndices.count
            
            let itemWidth = width / CGFloat(itemsInThisRow)
            var xOffset = bounds.minX
            
            // First pass: measure max height for this row
            var rowHeight: CGFloat = 0
            for index in rowIndices {
                let size = subviews[index].sizeThatFits(ProposedViewSize(width: itemWidth, height: nil))
                rowHeight = max(rowHeight, size.height)
            }
            
            // Second pass: place items
            for index in rowIndices {
                let subview = subviews[index]
                let proposal = ProposedViewSize(width: itemWidth, height: rowHeight)
                
                subview.place(at: CGPoint(x: xOffset, y: yOffset), proposal: proposal)
                
                xOffset += itemWidth
            }
            
            yOffset += rowHeight
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 40) {
            Section("1 Item") {
                WrapRow(maxColumns: 3) {
                    Color.red.frame(height: 100)
                        .overlay(Text("1"))
                }
            }
            
            Section("2 Items") {
                WrapRow(maxColumns: 3) {
                    Color.red.frame(height: 100).overlay(Text("1"))
                    Color.blue.frame(height: 100).overlay(Text("2"))
                }
            }
            
            Section("3 Items") {
                WrapRow(maxColumns: 3) {
                    Color.red.frame(height: 100).overlay(Text("1"))
                    Color.blue.frame(height: 100).overlay(Text("2"))
                    Color.green.frame(height: 100).overlay(Text("3"))
                }
            }
            
            Section("4 Items (3 + 1)") {
                WrapRow(maxColumns: 3) {
                    Color.red.frame(height: 100).overlay(Text("1"))
                    Color.blue.frame(height: 100).overlay(Text("2"))
                    Color.green.frame(height: 100).overlay(Text("3"))
                    Color.orange.frame(height: 100).overlay(Text("4"))
                }
            }
            
            Section("Mixed Views") {
                WrapRow(maxColumns: 3) {
                    Text("Text 1")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.yellow)
                    
                    Image(systemName: "star.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding()
                        .frame(height: 100)
                        .frame(maxWidth: .infinity)
                        .background(Color.purple)
                }
            }

            Section("Mixed Wrapping (4 items)") {
                WrapRow(maxColumns: 3) {
                    Text("1")
                        .frame(maxWidth: .infinity)
                        .frame(height: 80)
                        .background(Color.yellow)
                    
                    Text("2")
                        .frame(maxWidth: .infinity)
                        .frame(height: 80)
                        .background(Color.orange)
                    
                    Text("3")
                        .frame(maxWidth: .infinity)
                        .frame(height: 80)
                        .background(Color.red)

                    Image(systemName: "star.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding()
                        .frame(height: 100)
                        .frame(maxWidth: .infinity)
                        .background(Color.purple)
                }
            }
        }
        .padding()
    }
}
