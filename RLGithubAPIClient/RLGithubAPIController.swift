//
//  RLGithubAPIController.swift
//  RLGithubAPIClient
//
//  Created by Randall Leung on 1/5/15.
//  Copyright (c) 2015 Randall Leung. All rights reserved.
//

import UIKit

class RLGithubAPIController {
    var mySession: NSURLSession?
    var accessToken: String?
    let clientID = "client_id=\(Constants.kClientID)"
    let clientSecret = "client_secret=\(Constants.kClientSecret)"
    let redirectURL = "redirect_uri=\(Constants.kRedirectURL)"
    let githubOAuthUrl = "https://github.com/login/oauth/authorize?"
    let scope = "scope=user,repo"
    let githubPOSTURL = "https://github.com/login/oauth/access_token"
    
    init() {
        if self.mySession == nil {
            if let tokenValue = NSUserDefaults.standardUserDefaults().valueForKey("GithubKey") as? String {
                self.accessToken = tokenValue
                var sessionConfiguration = NSURLSessionConfiguration.defaultSessionConfiguration()
                var HTTPAdditionalHeaders = ["Authorization" : "token \(self.accessToken!)"]
                sessionConfiguration.HTTPAdditionalHeaders = HTTPAdditionalHeaders
                self.mySession = NSURLSession(configuration: sessionConfiguration)
            }
        }
    }
  
    //Singleton Class
    class var controller : RLGithubAPIController {
    struct Static {
        static var onceToken : dispatch_once_t = 0
        static var instance : RLGithubAPIController? = nil
    }
    dispatch_once(&Static.onceToken) {
        Static.instance = RLGithubAPIController()
    }
        return Static.instance!
    }
  
    //Take user and send to Github to request Access
    func requestOAuthAccess() {
        let url = githubOAuthUrl + clientID + "&" + redirectURL + "&" + scope
        UIApplication.sharedApplication().openURL(NSURL(string: url)!)
    }
    
    
    func handleOAuthURL(callbackURL: NSURL) {
        let query = callbackURL.query
        let components = query?.componentsSeparatedByString("code=")
        let code = components?.last
        let urlQuery = clientID + "&" + clientSecret + "&" + "code=\(code!)"
        var request = NSMutableURLRequest(URL: NSURL(string: githubPOSTURL)!)
        request.HTTPMethod = "POST"
        var postData = urlQuery.dataUsingEncoding(NSASCIIStringEncoding, allowLossyConversion: true)
        let length = postData!.length
        request.setValue("\(length)", forHTTPHeaderField: "Content-Length")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.HTTPBody = postData
        
        let dataTask: Void = NSURLSession.sharedSession().dataTaskWithRequest(request, completionHandler: { (data, response, error) -> Void in
            if error != nil {
                println("\(error)")
            } else {
                if let httpResponse = response as? NSHTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200...204:
                        var tokenResponse = NSString(data: data, encoding: NSASCIIStringEncoding)
                        var accessTokenComponent = tokenResponse?.componentsSeparatedByString("access_token=")
                        let accessTokenComponentBack: AnyObject = accessTokenComponent![1]
                        accessTokenComponent = accessTokenComponentBack.componentsSeparatedByString("&scope")
                        self.accessToken = accessTokenComponent?.first as? NSString
                        println("The accessToken is: \(self.accessToken!)")
                        
                        var configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
                        configuration.HTTPAdditionalHeaders = ["Authorization": "token accessToken"]
                        self.mySession = NSURLSession(configuration: configuration)
                        
                        NSUserDefaults.standardUserDefaults().setObject("\(self.accessToken!)", forKey: "MyKey")
                        NSUserDefaults.standardUserDefaults().synchronize()
                    default:
                        println("Default case on status code")
                    }
                }
            }
        }).resume()
    }
    
    func fetchRepoWithSearchTerm(repoName: String?, completionHandler: (errorDescription: String?, response: NSDictionary?) -> (Void)) {
        let formattedSearchTerm = repoName?.stringByReplacingOccurrencesOfString(" ", withString: "+", options: NSStringCompareOptions.LiteralSearch, range: nil)
        
        let url = NSURL(string: "https://api.github.com/search/repositories?q=\(formattedSearchTerm!)")
        let dataTask = NSURLSession.sharedSession().dataTaskWithURL(url!, completionHandler: { (data, response, error) -> Void in
            if let httpResponse = response as? NSHTTPURLResponse {
                switch httpResponse.statusCode {
                case 200...204:
                    for header in httpResponse.allHeaderFields {
                        println(header)
                    }
                    let responseString = NSString(data: data, encoding: NSUTF8StringEncoding)
                    
                    let responseDictionary = NSJSONSerialization.JSONObjectWithData(data, options: nil, error: nil) as? NSDictionary
                    
                    NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
                        completionHandler(errorDescription: nil, response: responseDictionary)
                    })
                case 400...499:
                    println("This is the clients fault")
                    println(httpResponse.description)
                    completionHandler(errorDescription: "This is the client's fault", response: nil)
                case 500...599:
                    println("This is the servers fault")
                    println(httpResponse.description)
                    completionHandler(errorDescription: "This is the servers's fault", response: nil)
                default:
                    println("Bad Response - \(httpResponse.statusCode)")
                }
            }
        })
        dataTask.resume()
    }
    
  
  
}


