import Foundation

/// Маппер для преобразования iCloud отчетов
struct ICloudReportMapper {
    
    /// Преобразовать DomainICloudReport в DomainPost
    static func toDomainPost(_ iCloudReport: DomainICloudReport) -> DomainPost {
        // Парсим содержимое отчета для извлечения goodItems и badItems
        let (goodItems, badItems) = parseReportContent(iCloudReport.reportContent)
        
        return DomainPost(
            id: iCloudReport.id,
            date: iCloudReport.date,
            goodItems: goodItems,
            badItems: badItems,
            published: true, // iCloud отчеты считаются опубликованными
            voiceNotes: [], // iCloud отчеты не содержат голосовых заметок
            type: .iCloud,
            isEvaluated: nil,
            evaluationResults: nil,
            authorUsername: iCloudReport.username,
            authorFirstName: nil,
            authorLastName: nil,
            isExternal: true, // iCloud отчеты считаются внешними
            externalVoiceNoteURLs: nil,
            externalText: iCloudReport.reportContent,
            externalMessageId: nil,
            authorId: nil
        )
    }
    
    /// Преобразовать DomainPost в DomainICloudReport
    static func toDomainICloudReport(_ domainPost: DomainPost, deviceName: String, deviceIdentifier: String) -> DomainICloudReport {
        return DomainICloudReport(
            id: domainPost.id,
            date: domainPost.date,
            deviceName: deviceName,
            deviceIdentifier: deviceIdentifier,
            username: domainPost.authorUsername,
            reportContent: domainPost.externalText ?? formatPostContent(domainPost),
            reportType: domainPost.type,
            timestamp: Date()
        )
    }
    
    /// Преобразовать массив DomainICloudReport в массив DomainPost
    static func toDomainPosts(_ iCloudReports: [DomainICloudReport]) -> [DomainPost] {
        return iCloudReports.map { toDomainPost($0) }
    }
    
    /// Преобразовать массив DomainPost в массив DomainICloudReport
    static func toDomainICloudReports(_ domainPosts: [DomainPost], deviceName: String, deviceIdentifier: String) -> [DomainICloudReport] {
        return domainPosts.map { toDomainICloudReport($0, deviceName: deviceName, deviceIdentifier: deviceIdentifier) }
    }
    
    // MARK: - Private Methods
    
    /// Парсить содержимое отчета для извлечения goodItems и badItems
    private static func parseReportContent(_ content: String) -> ([String], [String]) {
        var goodItems: [String] = []
        var badItems: [String] = []
        
        let lines = content.components(separatedBy: .newlines)
        var currentSection: String? = nil
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.isEmpty { continue }
            
            // Определяем секцию
            if trimmedLine.contains("✅") || trimmedLine.contains("Хорошие дела:") {
                currentSection = "good"
                continue
            } else if trimmedLine.contains("❌") || trimmedLine.contains("Плохие дела:") {
                currentSection = "bad"
                continue
            }
            
            // Добавляем элементы в соответствующую секцию
            if let section = currentSection {
                let item = trimmedLine.replacingOccurrences(of: "• ", with: "")
                    .replacingOccurrences(of: "- ", with: "")
                    .trimmingCharacters(in: .whitespaces)
                
                if !item.isEmpty {
                    switch section {
                    case "good":
                        goodItems.append(item)
                    case "bad":
                        badItems.append(item)
                    default:
                        break
                    }
                }
            }
        }
        
        return (goodItems, badItems)
    }
    
    /// Форматировать содержимое поста для iCloud
    private static func formatPostContent(_ post: DomainPost) -> String {
        var content = ""
        
        if !post.goodItems.isEmpty {
            content += "✅ Хорошие дела:\n"
            for item in post.goodItems {
                if !item.trimmingCharacters(in: .whitespaces).isEmpty {
                    content += "• \(item)\n"
                }
            }
            content += "\n"
        }
        
        if !post.badItems.isEmpty {
            content += "❌ Плохие дела:\n"
            for item in post.badItems {
                if !item.trimmingCharacters(in: .whitespaces).isEmpty {
                    content += "• \(item)\n"
                }
            }
            content += "\n"
        }
        
        return content
    }
} 